#include "ieee754_math.h"

#include <string.h>

#include "ieee754_model.h"

// binary64 bit patterns of the constants.
#define LN2_HI 0x3FE62E42FEFA39EFull  // ln(2) rounded to binary64
#define LN2_LO 0x3C7ABC9E3B39803Full  // ln(2) - LN2_HI
#define INV_LN2 0x3FF71547652B82FEull
#define SQRT2 0x3FF6A09E667F3BCDull

// 1/n! for n = 2 .. 15.
static const uint64_t inv_fact[] = {
    0x3FE0000000000000ull, 0x3FC5555555555555ull, 0x3FA5555555555555ull,
    0x3F81111111111111ull, 0x3F56C16C16C16C17ull, 0x3F2A01A01A01A01Aull,
    0x3EFA01A01A01A01Aull, 0x3EC71DE3A556C734ull, 0x3E927E4FB7789F5Cull,
    0x3E5AE64567F544E4ull, 0x3E21EED8EFF8D898ull, 0x3DE6124613A86D09ull,
    0x3DA93974A8C07C9Dull, 0x3D6AE7F3E733B81Full};

// -log2 of the truncation bound of the exp series up to r**n/n!, |r| <= 0.35, n = 2 .. 15.
static const int exp_bound[] = {7, 10, 14, 18, 22, 27, 32, 36, 41, 47, 52, 57, 62, 68};

// 2/(2i+1) for i = 1 .. 13: the atanh series of log.
static const uint64_t atanh_coef[] = {
    0x3FE5555555555555ull, 0x3FD999999999999Aull, 0x3FD2492492492492ull,
    0x3FCC71C71C71C71Cull, 0x3FC745D1745D1746ull, 0x3FC3B13B13B13B14ull,
    0x3FC1111111111111ull, 0x3FBE1E1E1E1E1E1Eull, 0x3FBAF286BCA1AF28ull,
    0x3FB8618618618618ull, 0x3FB642C8590B2164ull, 0x3FB47AE147AE147Bull,
    0x3FB2F684BDA12F68ull};

// -log2 of the relative truncation bound of the atanh series up to i terms,
// |s| <= 0.1716, i = 1 .. 13.
static const int log_bound[] = {12, 18, 23, 28, 34, 39, 44, 50, 55, 60, 65, 70, 76};

typedef struct {
  int data_w;
  int exp_w;
  int f_w;  // fraction bits
  int p;    // precision, f_w + 1
  int bias;
  uint64_t sign;
  uint64_t frac;
} fmt;

static fmt make_fmt(int data_w, int exp_w) {
  fmt f;
  f.data_w = data_w;
  f.exp_w = exp_w;
  f.f_w = data_w - exp_w - 1;
  f.p = f.f_w + 1;
  f.bias = (1 << (exp_w - 1)) - 1;
  f.sign = (uint64_t)1 << (data_w - 1);
  f.frac = ((uint64_t)1 << f.f_w) - 1;
  return f;
}

static uint64_t add(const fmt *f, uint64_t a, uint64_t b) {
  return ieee754_add(a, b, f->data_w, f->exp_w);
}
static uint64_t sub(const fmt *f, uint64_t a, uint64_t b) {
  return ieee754_sub(a, b, f->data_w, f->exp_w);
}
static uint64_t mul(const fmt *f, uint64_t a, uint64_t b) {
  return ieee754_mul(a, b, f->data_w, f->exp_w);
}
static uint64_t dvd(const fmt *f, uint64_t a, uint64_t b) {
  return ieee754_div(a, b, f->data_w, f->exp_w);
}

// Rounds a binary64 bit pattern to the format.
static uint64_t cst(const fmt *f, uint64_t bits64) {
  double value;
  memcpy(&value, &bits64, sizeof value);
  return ieee754_from_double(value, f->data_w, f->exp_w);
}

static int exp_field(const fmt *f, uint64_t x) {
  return (int)(x >> f->f_w) & ((1 << f->exp_w) - 1);
}

static int is_special(const fmt *f, uint64_t x) { return exp_field(f, x) == (1 << f->exp_w) - 1; }

static uint64_t inf_bits(const fmt *f) { return (uint64_t)((1 << f->exp_w) - 1) << f->f_w; }

static uint64_t nan_bits(const fmt *f) {
  return inf_bits(f) | ((uint64_t)1 << (f->f_w - 1));
}

// 2**k for a normal power of two.
static uint64_t pow2(const fmt *f, int k) { return (uint64_t)(k + f->bias) << f->f_w; }

static uint64_t with_exp(const fmt *f, uint64_t x, int k) { return (x & f->frac) | pow2(f, k); }

static int bit_length(uint64_t n) {
  int len = 0;
  while (n) {
    len++;
    n >>= 1;
  }
  return len;
}

// Exact encoding of an integer with |n| < 2**p.
static uint64_t from_int(const fmt *f, int n) {
  if (n == 0) return 0;
  uint64_t sign = n < 0 ? f->sign : 0;
  uint64_t u = (uint64_t)(n < 0 ? -n : n);
  int msb = bit_length(u) - 1;
  return sign | pow2(f, msb) | ((u << (f->f_w - msb)) & f->frac);
}

// Integer value of an integer-valued encoding.
static int to_int(const fmt *f, uint64_t x) {
  int e = exp_field(f, x) - f->bias;
  if (exp_field(f, x) == 0 || e < 0) return 0;
  int value = (int)(((x & f->frac) | (f->frac + 1)) >> (f->f_w - e));
  return x & f->sign ? -value : value;
}

// x = m * 2**e with m in [1, 2), for a positive finite non-zero x.
static void split(const fmt *f, uint64_t x, uint64_t *m, int *e) {
  int field = exp_field(f, x);
  uint64_t frac = x & f->frac;
  if (field) {
    *e = field - f->bias;
  } else {
    int shift = f->f_w + 1 - bit_length(frac);
    frac = (frac << shift) & f->frac;
    *e = 1 - f->bias - shift;
  }
  *m = frac | pow2(f, 0);
}

// y * 2**k for a positive normal y, rounded once.
static uint64_t scale(const fmt *f, uint64_t y, int k) {
  int emin = 1 - f->bias;
  int e = exp_field(f, y) - f->bias + k;
  if (e > f->bias) return inf_bits(f);
  if (e >= emin) return with_exp(f, y, e);
  y = with_exp(f, y, emin);
  k = e - emin;
  while (k < emin) {
    y = mul(f, y, pow2(f, emin));
    k -= emin;
  }
  return mul(f, y, pow2(f, k));
}

// ln(2) = hi + lo, where hi has p - int_bits significant bits so that n * hi is exact
// for |n| < 2**int_bits.
static void ln2_parts(const fmt *f, int int_bits, uint64_t *hi, uint64_t *lo) {
  int drop = 53 - (f->p - int_bits);
  uint64_t hi64 = LN2_HI & ~(((uint64_t)1 << drop) - 1);
  uint64_t lo64 = ieee754_add(ieee754_sub(LN2_HI, hi64, 64, 11), LN2_LO, 64, 11);
  *hi = cst(f, hi64);
  *lo = cst(f, lo64);
}

uint64_t ieee754_fabs(uint64_t a, int data_w, int exp_w) {
  fmt f = make_fmt(data_w, exp_w);
  return a & ~f.sign;
}

uint64_t ieee754_sqrt(uint64_t a, int data_w, int exp_w) {
  fmt f = make_fmt(data_w, exp_w);
  uint64_t mag = a & ~f.sign;
  if (is_special(&f, a) && (a & f.frac)) return nan_bits(&f);
  if (mag == 0) return a;
  if (a & f.sign) return nan_bits(&f);
  if (is_special(&f, a)) return a;

  // a = m * 2**e with m in [1, 4) and e even
  uint64_t m;
  int e;
  split(&f, a, &m, &e);
  if (e & 1) {
    m = with_exp(&f, m, 1);
    e -= 1;
  }

  // Halving the encoding offset from 1.0 gives sqrt(m) within 2**-4; each Newton step
  // doubles the correct bits.
  uint64_t y = (m + pow2(&f, 0)) >> 1;
  uint64_t half = pow2(&f, -1);
  for (int bits = 4; bits < f.p + 2; bits = 2 * bits + 1) {
    y = mul(&f, half, add(&f, y, dvd(&f, m, y)));
  }
  return scale(&f, y, e / 2);
}

uint64_t ieee754_exp(uint64_t a, int data_w, int exp_w) {
  fmt f = make_fmt(data_w, exp_w);
  int negative = (a & f.sign) != 0;
  if (is_special(&f, a)) {
    if (a & f.frac) return nan_bits(&f);
    return negative ? 0 : inf_bits(&f);
  }

  // |a| >= 2**range overflows or underflows
  int range = bit_length((uint64_t)(((f.bias + f.p + 1) * 710) / 1024 + 1));
  if (exp_field(&f, a) - f.bias >= range) return negative ? 0 : inf_bits(&f);

  // a = k * ln(2) + r with |r| <= ln(2)/2
  uint64_t magic = pow2(&f, f.p - 1) | ((uint64_t)1 << (f.f_w - 1));
  uint64_t kd = sub(&f, add(&f, mul(&f, a, cst(&f, INV_LN2)), magic), magic);
  uint64_t hi, lo;
  ln2_parts(&f, range + 1, &hi, &lo);
  uint64_t r_hi = sub(&f, a, mul(&f, kd, hi));
  uint64_t r_lo = mul(&f, kd, lo);
  uint64_t r = sub(&f, r_hi, r_lo);

  // e**r = 1 + (r_hi + (r**2 * q - r_lo)), q = 1/2! + r/3! + ... + r**(n-2)/n!
  int n = 2;
  while (exp_bound[n - 2] < f.p + 2) n++;
  uint64_t q = cst(&f, inv_fact[n - 2]);
  for (int i = n - 1; i >= 2; i--) q = add(&f, cst(&f, inv_fact[i - 2]), mul(&f, r, q));
  uint64_t t = sub(&f, mul(&f, mul(&f, r, r), q), r_lo);
  uint64_t y = add(&f, pow2(&f, 0), add(&f, r_hi, t));
  return scale(&f, y, to_int(&f, kd));
}

uint64_t ieee754_log(uint64_t a, int data_w, int exp_w) {
  fmt f = make_fmt(data_w, exp_w);
  uint64_t mag = a & ~f.sign;
  if (is_special(&f, a) && (a & f.frac)) return nan_bits(&f);
  if (mag == 0) return f.sign | inf_bits(&f);
  if (a & f.sign) return nan_bits(&f);
  if (is_special(&f, a)) return a;

  // a = m * 2**e with m in [sqrt(2)/2, sqrt(2)]
  uint64_t m;
  int e;
  split(&f, a, &m, &e);
  if ((m & f.frac) > (cst(&f, SQRT2) & f.frac)) {
    m = with_exp(&f, m, -1);
    e += 1;
  }

  // log(m) = 2 atanh(s) = d - hfsq + s * (hfsq + R), d = m - 1, s = d / (2 + d),
  // hfsq = d**2 / 2, R = z * (2/3 + z * (2/5 + ...)), z = s**2
  uint64_t d = sub(&f, m, pow2(&f, 0));
  uint64_t hfsq = mul(&f, pow2(&f, -1), mul(&f, d, d));
  uint64_t s = dvd(&f, d, add(&f, pow2(&f, 1), d));
  uint64_t z = mul(&f, s, s);
  int n = 1;
  while (log_bound[n - 1] < f.p + 2) n++;
  uint64_t rr = cst(&f, atanh_coef[n - 1]);
  for (int i = n - 1; i >= 1; i--) rr = add(&f, cst(&f, atanh_coef[i - 1]), mul(&f, z, rr));
  rr = mul(&f, z, rr);
  uint64_t tail = mul(&f, s, add(&f, hfsq, rr));
  if (e == 0) return sub(&f, d, sub(&f, hfsq, tail));

  // log(a) = e * ln(2) + log(m), with e * hi exact
  uint64_t hi, lo;
  ln2_parts(&f, bit_length((uint64_t)(f.bias + f.p)), &hi, &lo);
  uint64_t ed = from_int(&f, e);
  return sub(&f, mul(&f, ed, hi), sub(&f, sub(&f, hfsq, add(&f, tail, mul(&f, ed, lo))), d));
}
