#include "ieee754_model.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned __int128 u128;

enum { EXTRA = 3 };

typedef struct {
  int data_w;
  int exp_w;
  int man_w;
  int f_w;
  int bias;
  uint32_t exp_mask;  // the internal exponent has exp_w + 2 bits
  int special;        // IEEE754_SPECIAL_*
} format;

static int special_kind = IEEE754_SPECIAL_IEEE;

void ieee754_set_special(int kind) { special_kind = kind; }

int ieee754_get_special(void) { return special_kind; }

typedef struct {
  int nan;
  int inf;
  int zero;
  int sign;
  uint32_t exp;
  u128 man;
} unpacked;

static u128 mask(int width) {
  if (width <= 0) return 0;
  return width >= 128 ? ~(u128)0 : ((u128)1 << width) - 1;
}

static u128 shift_left(u128 value, uint32_t shift) { return shift >= 128 ? 0 : value << shift; }

// cls: number of leading bits equal to symbol.
static uint32_t count_leading(u128 data, int width, int symbol) {
  for (int i = width - 1; i >= 0; i--) {
    if ((int)((data >> i) & 1) != symbol) return (uint32_t)(width - 1 - i);
  }
  return (uint32_t)width;
}

static format make_format(int data_w, int exp_w) {
  format f;
  f.data_w = data_w;
  f.exp_w = exp_w;
  f.man_w = data_w - exp_w;
  f.f_w = f.man_w - 1;
  f.bias = (1 << (exp_w - 1)) - 1;
  f.exp_mask = (1u << (exp_w + 2)) - 1;
  f.special = special_kind;
  return f;
}

static int exp_negative(const format *f, uint32_t value) {
  return (int)((value >> (f->exp_w + 1)) & 1);
}

static int32_t exp_signed(const format *f, uint32_t value) {
  return exp_negative(f, value) ? (int32_t)(value | ~f->exp_mask) : (int32_t)value;
}

// The largest exponent field of a finite number
static uint32_t exp_field_max(const format *f) {
  return f->special == IEEE754_SPECIAL_IEEE ? (1u << f->exp_w) - 2 : (1u << f->exp_w) - 1;
}

// The largest finite number of a sign
static u128 max_bits(const format *f, int sign) {
  u128 frac = (u128)mask(f->f_w) - (f->special == IEEE754_SPECIAL_FN);
  return ((u128)sign << (f->data_w - 1)) | ((u128)exp_field_max(f) << f->f_w) | frac;
}

// Without NaN (FINITE), an invalid operation gives the largest finite number
static u128 nan_bits(const format *f) {
  if (f->special == IEEE754_SPECIAL_FN) return (u128)mask(f->data_w - 1);
  if (f->special == IEEE754_SPECIAL_FINITE) return max_bits(f, 0);
  return ((u128)((1u << f->exp_w) - 1) << f->f_w) | ((u128)1 << (f->f_w - 1));
}

// Without infinities (FN, FINITE), infinity saturates to the largest finite number
static u128 inf_bits(const format *f, int sign) {
  if (f->special != IEEE754_SPECIAL_IEEE) return max_bits(f, sign);
  return ((u128)sign << (f->data_w - 1)) | ((u128)((1u << f->exp_w) - 1) << f->f_w);
}

static unpacked unpack(const format *f, u128 bits) {
  unpacked u;
  uint32_t exp_field = (uint32_t)(bits >> f->f_w) & ((1u << f->exp_w) - 1);
  u128 fraction = bits & (u128)mask(f->f_w);
  int exp_ones = exp_field == (1u << f->exp_w) - 1;
  if (f->special == IEEE754_SPECIAL_IEEE) {
    u.nan = exp_ones && fraction != 0;
    u.inf = exp_ones && fraction == 0;
  } else {
    u.nan = f->special == IEEE754_SPECIAL_FN && exp_ones && fraction == (u128)mask(f->f_w);
    u.inf = 0;
  }
  u.zero = exp_field == 0 && fraction == 0;
  u.sign = (int)(bits >> (f->data_w - 1)) & 1;
  u.exp = exp_field ? exp_field : 1;
  u.man = fraction | ((u128)(exp_field != 0) << f->f_w);
  return u;
}

// norm: reduces a 2*man_w mantissa to man_w + 3 bits and adjusts the exponent.
static void normalize(const format *f, uint32_t exp_i, u128 man_i, int inv, uint32_t *exp_o,
                      u128 *man_o) {
  int man2_w = 2 * f->man_w;
  uint32_t rshift_lim = (uint32_t)f->man_w + 2;
  uint32_t lsc = count_leading(man_i, man2_w, inv);

  uint32_t exp_diff = (lsc - exp_i) & f->exp_mask;
  uint32_t exp_diff2 = (0u - exp_i) & f->exp_mask;
  uint32_t lshift = exp_negative(f, exp_diff) ? lsc : exp_i;
  uint32_t rshift = exp_diff2 > rshift_lim ? rshift_lim : exp_diff2;

  u128 man_norm;
  if (exp_negative(f, exp_diff2)) {
    man_norm = shift_left(man_i, lshift) & mask(man2_w);
  } else {
    u128 shifted = man_i >> rshift;
    int sticky = (shifted & 1) != 0 || (man_i & mask((int)rshift)) != 0;
    man_norm = (shifted & ~(u128)1) | (u128)sticky;
  }

  *exp_o = (exp_i + (~lshift & f->exp_mask) + 2) & f->exp_mask;
  u128 top = (u128)((man_norm >> (f->man_w - 2)) & mask(f->man_w + 2));
  *man_o = (top << 1) | (u128)((man_norm & mask(f->man_w - 2)) != 0);
}

static int rounding_mode = IEEE754_RNE;

void ieee754_set_rounding(int mode) { rounding_mode = mode & 7; }

int ieee754_get_rounding(void) { return rounding_mode; }

// round and pack in rounding mode rnd.
static u128 pack(const format *f, int rnd, int inv, int nsub, int sign_i, uint32_t exp_i,
                     u128 man_i) {
  // With inv, the magnitude is the inverted mantissa plus one unit of the sticky bit
  u128 man_inv = inv ? man_i ^ (u128)mask(f->man_w + EXTRA) : man_i;
  unsigned grs = (unsigned)(man_inv & 7) + (unsigned)inv;
  int carry = (grs >> 3) & 1;
  int lsb = (int)(man_inv >> 3) & 1;
  int guard = (grs >> 2) & 1;
  int rnd_bit = (grs >> 1) & 1;
  int sticky = grs & 1;
  int inexact = guard | rnd_bit | sticky;

  int up;
  switch (rnd) {
    case IEEE754_RTZ: up = 0; break;
    case IEEE754_RDN: up = sign_i && inexact; break;
    case IEEE754_RUP: up = !sign_i && inexact; break;
    case IEEE754_RMM: up = guard; break;
    default: up = guard & (lsb | rnd_bit | sticky); break;
  }
  int round_up = carry | up;

  u128 man_rnd = (man_inv >> 3) + (u128)round_up;
  uint32_t exp_rnd = exp_i;
  if ((man_rnd >> f->man_w) & 1) {
    man_rnd >>= 1;
    exp_rnd = (exp_i + 1) & f->exp_mask;
  }
  man_rnd &= (u128)mask(f->man_w);

  // Overflow gives infinity, or the largest finite number when the mode rounds toward
  // zero for the sign of the result. A zero mantissa is never an overflow: the exponent
  // of a zero sum can wrap.
  uint32_t exp_max = exp_field_max(f);
  int ovf = man_rnd != 0 && exp_negative(f, (exp_max - exp_rnd) & f->exp_mask);
  // FN: the largest exponent with an all-ones fraction is NaN, so it overflows too
  ovf |= f->special == IEEE754_SPECIAL_FN && exp_rnd == exp_max && (man_rnd & mask(f->f_w)) == mask(f->f_w) &&
         (man_rnd >> f->f_w) & 1;
  if (ovf && f->special != IEEE754_SPECIAL_IEEE) return max_bits(f, sign_i);  // saturate
  if (ovf) {
    int ovf_inf = rnd == IEEE754_RTZ ? 0 : rnd == IEEE754_RDN ? sign_i : rnd == IEEE754_RUP ? !sign_i : 1;
    exp_rnd = ovf_inf ? (1u << f->exp_w) - 1 : exp_max;
    man_rnd = ovf_inf ? (u128)1 << f->f_w : (u128)mask(f->man_w);
  }
  exp_rnd &= (1u << f->exp_w) - 1;

  int nzero = man_i != 0 || round_up;
  u128 exponent = (man_rnd >> f->f_w) & 1 ? exp_rnd : 0;
  // An exact zero from operands of opposite signs is +0, or -0 when rounding toward -infinity
  int sign = (nzero || nsub) ? sign_i : rnd == IEEE754_RDN;
  return ((u128)sign << (f->data_w - 1)) | (exponent << f->f_w) |
         (man_rnd & (u128)mask(f->f_w));
}

static u128 add_unpacked(const format *f, unpacked a, unpacked b) {
  if (a.nan || a.inf || b.nan || b.inf) {
    if (a.nan || b.nan || (a.inf && b.inf && a.sign != b.sign)) return nan_bits(f);
    return b.inf ? inf_bits(f, b.sign) : inf_bits(f, a.sign);
  }

  unpacked big = a.exp >= b.exp ? a : b;
  unpacked small = a.exp >= b.exp ? b : a;

  int sticky_w = f->man_w + 2;
  uint32_t rshift_lim = (uint32_t)sticky_w & ((1u << f->exp_w) - 1);
  uint32_t diff = (big.exp - small.exp) & ((1u << f->exp_w) - 1);
  uint32_t rshift = diff > rshift_lim ? rshift_lim : diff;
  u128 small_in = ((u128)small.man << sticky_w) >> rshift;
  int sticky = (small_in & mask(sticky_w - 2)) != 0;

  int subtract = big.sign ^ small.sign;
  u128 big_inv = (u128)big.man << EXTRA;
  if (subtract) big_inv = ~big_inv & mask(f->man_w + EXTRA);

  u128 small_reg = (((small_in >> (sticky_w - 2)) & mask(f->man_w + EXTRA - 1)) << 1) | (u128)sticky;
  u128 big_ext = big_inv | ((u128)subtract << (f->man_w + EXTRA));
  u128 temp = (big_ext + small_reg + (u128)subtract) & mask(f->man_w + EXTRA + 1);

  int top = (int)(temp >> (f->man_w + EXTRA)) & 1;
  int res_sign = subtract ? (!big.sign) ^ top : big.sign;
  int res_inv = subtract & top;

  uint32_t exp_norm;
  u128 man_norm;
  normalize(f, big.exp, temp << (f->man_w - EXTRA - 1), res_inv, &exp_norm, &man_norm);
  return pack(f, rounding_mode, res_inv, !subtract, res_sign, exp_norm, man_norm);
}

uint64_t ieee754_add(uint64_t a, uint64_t b, int data_w, int exp_w) {
  format f = make_format(data_w, exp_w);
  return add_unpacked(&f, unpack(&f, a), unpack(&f, b));
}

uint64_t ieee754_sub(uint64_t a, uint64_t b, int data_w, int exp_w) {
  format f = make_format(data_w, exp_w);
  unpacked ub = unpack(&f, b);
  ub.sign ^= 1;
  return add_unpacked(&f, unpack(&f, a), ub);
}

uint64_t ieee754_mul(uint64_t a, uint64_t b, int data_w, int exp_w) {
  format f = make_format(data_w, exp_w);
  unpacked ua = unpack(&f, a);
  unpacked ub = unpack(&f, b);
  int sign = ua.sign ^ ub.sign;

  if (ua.nan || ua.inf || ub.nan || ub.inf) {
    if (ua.nan || ub.nan || ua.zero || ub.zero) return nan_bits(&f);
    return inf_bits(&f, sign);
  }

  uint32_t exponent = (ua.exp + ub.exp - (uint32_t)f.bias) & f.exp_mask;
  uint32_t exp_norm;
  u128 man_norm;
  normalize(&f, exponent, (u128)ua.man * ub.man, 0, &exp_norm, &man_norm);
  return pack(&f, rounding_mode, 0, 1, sign, exp_norm, man_norm);
}

uint64_t ieee754_div(uint64_t a, uint64_t b, int data_w, int exp_w) {
  format f = make_format(data_w, exp_w);
  unpacked ua = unpack(&f, a);
  unpacked ub = unpack(&f, b);
  int sign = ua.sign ^ ub.sign;

  if (ua.nan || ua.inf || ub.nan || ub.inf || ub.zero) {
    if (ua.nan || ub.nan || (ua.inf && ub.inf) || (ua.zero && ub.zero)) return nan_bits(&f);
    if (ub.inf) return (u128)sign << (f.data_w - 1);
    return inf_bits(&f, sign);
  }

  uint32_t a_lz = count_leading(ua.man, f.man_w, 0);
  uint32_t b_lz = count_leading(ub.man, f.man_w, 0);
  u128 a_norm = shift_left(ua.man, a_lz) & mask(f.man_w);
  u128 b_norm = shift_left(ub.man, b_lz) & mask(f.man_w);

  u128 dividend = a_norm << (f.man_w + EXTRA);
  u128 quotient = dividend / b_norm;
  int remainder = dividend % b_norm != 0;

  uint32_t exponent = (ua.exp - ub.exp + (uint32_t)f.bias - a_lz + b_lz) & f.exp_mask;
  u128 top = (quotient >> 1) & mask(f.man_w + EXTRA);
  u128 low = (quotient & 1) | (u128)remainder;
  u128 man = ((top << 1) | low) << (f.man_w - EXTRA - 2);

  uint32_t exp_norm;
  u128 man_norm;
  normalize(&f, exponent, man, 0, &exp_norm, &man_norm);
  return pack(&f, rounding_mode, 0, 1, sign, exp_norm, man_norm);
}

int ieee754_format_ok(int data_w, int exp_w) {
  int man_w = data_w - exp_w;
  return data_w <= 64 && exp_w >= 2 && exp_w <= 11 && man_w >= 6 && man_w <= 53;
}

static u128 from_double(format f, double value) {
  uint64_t raw;
  memcpy(&raw, &value, sizeof raw);

  int sign = (int)(raw >> 63);
  int exp_d = (int)(raw >> 52) & 0x7ff;
  uint64_t man = raw & (((uint64_t)1 << 52) - 1);

  if (exp_d == 0x7ff) return man ? nan_bits(&f) : inf_bits(&f, sign);
  u128 sign_bits = (u128)sign << (f.data_w - 1);
  if (exp_d == 0 && man == 0) return sign_bits;

  // man in [2**52, 2**53) with value = man * 2**(exponent - 52)
  int exponent;
  if (exp_d == 0) {
    int lz = (int)count_leading(man, 53, 0);
    man <<= lz;
    exponent = 1 - 1023 - lz;
  } else {
    man |= (uint64_t)1 << 52;
    exponent = exp_d - 1023;
  }

  int exp_field = exponent + f.bias;
  int shift = 53 - f.man_w + (exp_field < 1 ? 1 - exp_field : 0);
  if (shift > 60) shift = 60;

  u128 kept;
  if (shift <= 0) {  // a format wider than binary64: exact
    kept = (u128)man << -shift;
  } else {
    kept = man >> shift;
    uint64_t rem = man & (((uint64_t)1 << shift) - 1);
    uint64_t half = (uint64_t)1 << (shift - 1);
    if (rem > half || (rem == half && (kept & 1))) kept++;
  }

  if (exp_field < 1) {
    u128 min_normal = (u128)1 << f.f_w;
    u128 field = kept >= min_normal ? min_normal : 0;
    return sign_bits | field | (kept & (min_normal - 1));
  }
  if (kept >> f.man_w) {
    kept >>= 1;
    exp_field++;
  }
  int emax = (int)exp_field_max(&f);
  if (exp_field > emax ||
      (f.special == IEEE754_SPECIAL_FN && exp_field == emax && (kept & mask(f.f_w)) == mask(f.f_w)))
    return inf_bits(&f, sign);
  return sign_bits | ((u128)exp_field << f.f_w) | (kept & mask(f.f_w));
}

uint64_t ieee754_from_double(double value, int data_w, int exp_w) {
  return (uint64_t)from_double(make_format(data_w, exp_w), value);
}

static double to_double(format f, u128 bits) {
  unpacked u = unpack(&f, bits);
  double magnitude;
  if (u.nan) {
    magnitude = NAN;
  } else if (u.inf) {
    magnitude = INFINITY;
  } else {
    magnitude = ldexp((double)u.man, (int)u.exp - f.bias - f.f_w);
  }
  return u.sign ? -magnitude : magnitude;
}

double ieee754_to_double(uint64_t bits, int data_w, int exp_w) { return to_double(make_format(data_w, exp_w), bits); }

// Accumulator words: native 128 bits, and 256 bits for formats up to binary128.
typedef u128 word128;
static inline word128 w128_from(u128 x) { return x; }
static inline u128 w128_lo(word128 x) { return x; }
static inline word128 w128_add(word128 a, word128 b) { return a + b; }
static inline word128 w128_and(word128 a, word128 b) { return a & b; }
static inline word128 w128_or(word128 a, word128 b) { return a | b; }
static inline word128 w128_not(word128 a) { return ~a; }
static inline word128 w128_shl(word128 a, uint32_t s) { return s >= 128 ? 0 : a << s; }
static inline word128 w128_shr(word128 a, uint32_t s) { return s >= 128 ? 0 : a >> s; }
static inline word128 w128_mask(int width) { return mask(width); }
static inline int w128_bit(word128 a, int i) { return (int)(a >> i) & 1; }
static inline int w128_nz(word128 a) { return a != 0; }
static inline word128 w128_mul(u128 a, u128 b) { return a * b; }

typedef struct {
  u128 lo, hi;
} word256;
static inline word256 w256_from(u128 x) { return (word256){x, 0}; }
static inline u128 w256_lo(word256 x) { return x.lo; }
static inline word256 w256_add(word256 a, word256 b) {
  u128 lo = a.lo + b.lo;
  return (word256){lo, a.hi + b.hi + (lo < a.lo)};
}
static inline word256 w256_and(word256 a, word256 b) { return (word256){a.lo & b.lo, a.hi & b.hi}; }
static inline word256 w256_or(word256 a, word256 b) { return (word256){a.lo | b.lo, a.hi | b.hi}; }
static inline word256 w256_not(word256 a) { return (word256){~a.lo, ~a.hi}; }
static inline word256 w256_shl(word256 a, uint32_t s) {
  if (s >= 256) return (word256){0, 0};
  if (s >= 128) return (word256){0, a.lo << (s - 128)};
  if (s == 0) return a;
  return (word256){a.lo << s, (a.hi << s) | (a.lo >> (128 - s))};
}
static inline word256 w256_shr(word256 a, uint32_t s) {
  if (s >= 256) return (word256){0, 0};
  if (s >= 128) return (word256){a.hi >> (s - 128), 0};
  if (s == 0) return a;
  return (word256){(a.lo >> s) | (a.hi << (128 - s)), a.hi >> s};
}
static inline word256 w256_mask(int width) {
  if (width <= 0) return (word256){0, 0};
  if (width >= 128) return (word256){~(u128)0, mask(width - 128)};
  return (word256){mask(width), 0};
}
static inline int w256_bit(word256 a, int i) {
  return i >= 128 ? (int)(a.hi >> (i - 128)) & 1 : (int)(a.lo >> i) & 1;
}
static inline int w256_nz(word256 a) { return a.lo != 0 || a.hi != 0; }
// a * b for a, b < 2^127
static inline word256 w256_mul(u128 a, u128 b) {
  uint64_t a0 = (uint64_t)a, a1 = (uint64_t)(a >> 64), b0 = (uint64_t)b, b1 = (uint64_t)(b >> 64);
  word256 r = w256_from((u128)a0 * b0);
  r = w256_add(r, w256_shl(w256_from((u128)a0 * b1), 64));
  r = w256_add(r, w256_shl(w256_from((u128)a1 * b0), 64));
  r.hi += (u128)a1 * b1;
  return r;
}

// The parameters of a mac unit, and its statistics
typedef struct {
  format f;
  int lguard_w;
  int rguard_w;
  int acc_w;
  int word_w;  // acc_w + EXTRA + 1
  uint32_t exp_zero;
  int step;  // largest left normalization shift per accumulation (1 in the RTL)
  int fb;    // feedback rounding (IEEE754_FB_ODD in the RTL)
  // statistics for architecture studies: accumulations of products, those that align
  // with a not fully normalized accumulator, and their missing normalization bits
  long stat_accs, stat_lagged, stat_lag_bits;
} mac_cfg;

#define W 128
#include "ieee754_mac.inc"
#undef W
#define W 256
#include "ieee754_mac.inc"
#undef W

struct ieee754_mac {
  mac_cfg c;
  int wide;  // a 256-bit accumulator word
  int pushed;
  int rnd;  // rounding mode at the last product
  mac_regs128 r;
  mac_regs256 r2;
};

// fmac and ffma also take precisions down to 2 (FP8, FP4) and formats up to binary128
static int mac_format_ok(int data_w, int exp_w) {
  int man_w = data_w - exp_w;
  return data_w <= 128 && exp_w >= 2 && exp_w <= 15 && man_w >= 2 && man_w <= 113;
}

ieee754_mac *ieee754_mac_new(int data_w, int exp_w, int lguard_w, int rguard_w) {
  if (!mac_format_ok(data_w, exp_w) || lguard_w < 0 || rguard_w < 0) return NULL;
  int acc_w = lguard_w + 1 + 2 * (data_w - exp_w) + rguard_w;
  if (acc_w + EXTRA + 1 > 256) return NULL;

  ieee754_mac *m = calloc(1, sizeof *m);
  if (!m) return NULL;
  m->c.f = make_format(data_w, exp_w);
  m->c.lguard_w = lguard_w;
  m->c.rguard_w = rguard_w;
  m->c.acc_w = acc_w;
  m->c.word_w = acc_w + EXTRA + 1;
  m->c.step = 1;
  m->c.exp_zero = (0u - ((1u << exp_w) + 2u * (uint32_t)m->c.f.man_w)) & m->c.f.exp_mask;
  m->wide = m->c.word_w > 128;
  return m;
}

void ieee754_mac_free(ieee754_mac *mac) { free(mac); }

void ieee754_mac_set_step(ieee754_mac *mac, int step) { mac->c.step = step < 1 ? 1 : step; }

void ieee754_mac_set_feedback(ieee754_mac *mac, int fb) { mac->c.fb = fb; }

void ieee754_mac_stats(const ieee754_mac *mac, long *accs, long *lagged, long *lag_bits) {
  *accs = mac->c.stat_accs;
  *lagged = mac->c.stat_lagged;
  *lag_bits = mac->c.stat_lag_bits;
}

void ieee754_mac_push_w(ieee754_mac *mac, ieee754_u128 a, ieee754_u128 b) {
  if (mac->wide)
    mac_clock256(&mac->c, &mac->r2, 1, a, b);
  else
    mac_clock128(&mac->c, &mac->r, 1, a, b);
  mac->pushed = 1;
  mac->rnd = rounding_mode;
}

ieee754_u128 ieee754_mac_result_w(ieee754_mac *mac) {
  if (!mac->pushed) return 0;
  mac->pushed = 0;
  return mac->wide ? mac_finish256(&mac->c, &mac->r2, mac->rnd) : mac_finish128(&mac->c, &mac->r, mac->rnd);
}

void ieee754_mac_push(ieee754_mac *mac, uint64_t a, uint64_t b) { ieee754_mac_push_w(mac, a, b); }

uint64_t ieee754_mac_result(ieee754_mac *mac) { return (uint64_t)ieee754_mac_result_w(mac); }

ieee754_u128 ieee754_from_double_w(double value, int data_w, int exp_w) {
  return from_double(make_format(data_w, exp_w), value);
}

double ieee754_to_double_w(ieee754_u128 bits, int data_w, int exp_w) {
  return to_double(make_format(data_w, exp_w), bits);
}

// ffma computes a*b + c correctly rounded, as the two-product stream a*b, c*1.0 of fmac
// does with its default guards
ieee754_u128 ieee754_fma_w(ieee754_u128 a, ieee754_u128 b, ieee754_u128 c, int data_w, int exp_w) {
  ieee754_mac *m = ieee754_mac_new(data_w, exp_w, 0, 0);
  if (!m) return 0;
  ieee754_mac_push_w(m, a, b);
  ieee754_mac_push_w(m, c, ieee754_from_double_w(1.0, data_w, exp_w));
  ieee754_u128 r = ieee754_mac_result_w(m);
  ieee754_mac_free(m);
  return r;
}

uint64_t ieee754_fma(uint64_t a, uint64_t b, uint64_t c, int data_w, int exp_w) {
  return (uint64_t)ieee754_fma_w(a, b, c, data_w, exp_w);
}
