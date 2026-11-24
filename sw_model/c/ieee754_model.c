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
} format;

typedef struct {
  int nan;
  int inf;
  int zero;
  int sign;
  uint32_t exp;
  uint64_t man;
} unpacked;

static u128 mask(int width) {
  if (width <= 0) return 0;
  return width >= 128 ? ~(u128)0 : ((u128)1 << width) - 1;
}

static u128 shift_left(u128 value, uint32_t shift) { return shift >= 128 ? 0 : value << shift; }

// Arithmetic right shift of a width-bit value.
static u128 shift_right_signed(u128 value, int width, uint32_t shift) {
  value &= mask(width);
  int negative = (int)(value >> (width - 1)) & 1;
  if (shift >= (uint32_t)width) return negative ? mask(width) : 0;
  u128 res = value >> shift;
  if (negative) res |= mask(width) & ~mask(width - (int)shift);
  return res;
}

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
  return f;
}

static int exp_negative(const format *f, uint32_t value) {
  return (int)((value >> (f->exp_w + 1)) & 1);
}

static int32_t exp_signed(const format *f, uint32_t value) {
  return exp_negative(f, value) ? (int32_t)(value | ~f->exp_mask) : (int32_t)value;
}

static uint64_t nan_bits(const format *f) {
  return ((uint64_t)((1u << f->exp_w) - 1) << f->f_w) | ((uint64_t)1 << (f->f_w - 1));
}

static uint64_t inf_bits(const format *f, int sign) {
  return ((uint64_t)sign << (f->data_w - 1)) | ((uint64_t)((1u << f->exp_w) - 1) << f->f_w);
}

static unpacked unpack(const format *f, uint64_t bits) {
  unpacked u;
  uint32_t exp_field = (uint32_t)(bits >> f->f_w) & ((1u << f->exp_w) - 1);
  uint64_t fraction = bits & (uint64_t)mask(f->f_w);
  int exp_ones = exp_field == (1u << f->exp_w) - 1;
  u.nan = exp_ones && fraction != 0;
  u.inf = exp_ones && fraction == 0;
  u.zero = exp_field == 0 && fraction == 0;
  u.sign = (int)(bits >> (f->data_w - 1)) & 1;
  u.exp = exp_field ? exp_field : 1;
  u.man = fraction | ((uint64_t)(exp_field != 0) << f->f_w);
  return u;
}

// norm: reduces a 2*man_w mantissa to man_w + 3 bits and adjusts the exponent.
static void normalize(const format *f, uint32_t exp_i, u128 man_i, int inv, uint32_t *exp_o,
                      uint64_t *man_o) {
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
  uint64_t top = (uint64_t)((man_norm >> (f->man_w - 2)) & mask(f->man_w + 2));
  *man_o = (top << 1) | (uint64_t)((man_norm & mask(f->man_w - 2)) != 0);
}

static int rounding_mode = IEEE754_RNE;

void ieee754_set_rounding(int mode) { rounding_mode = mode & 7; }

int ieee754_get_rounding(void) { return rounding_mode; }

// round and pack in rounding mode rnd.
static uint64_t pack(const format *f, int rnd, int inv, int nsub, int sign_i, uint32_t exp_i,
                     uint64_t man_i) {
  // With inv, the magnitude is the inverted mantissa plus one unit of the sticky bit
  uint64_t man_inv = inv ? man_i ^ (uint64_t)mask(f->man_w + EXTRA) : man_i;
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

  uint64_t man_rnd = (man_inv >> 3) + (uint64_t)round_up;
  uint32_t exp_rnd = exp_i;
  if ((man_rnd >> f->man_w) & 1) {
    man_rnd >>= 1;
    exp_rnd = (exp_i + 1) & f->exp_mask;
  }
  man_rnd &= (uint64_t)mask(f->man_w);

  // Overflow gives infinity, or the largest finite number when the mode rounds toward
  // zero for the sign of the result
  uint32_t exp_max = (1u << f->exp_w) - 2;
  if (exp_negative(f, (exp_max - exp_rnd) & f->exp_mask)) {
    int ovf_inf = rnd == IEEE754_RTZ ? 0 : rnd == IEEE754_RDN ? sign_i : rnd == IEEE754_RUP ? !sign_i : 1;
    exp_rnd = ovf_inf ? (1u << f->exp_w) - 1 : exp_max;
    man_rnd = ovf_inf ? (uint64_t)1 << f->f_w : (uint64_t)mask(f->man_w);
  }
  exp_rnd &= (1u << f->exp_w) - 1;

  int nzero = man_i != 0 || round_up;
  uint64_t exponent = (man_rnd >> f->f_w) & 1 ? exp_rnd : 0;
  // An exact zero from operands of opposite signs is +0, or -0 when rounding toward -infinity
  int sign = (nzero || nsub) ? sign_i : rnd == IEEE754_RDN;
  return ((uint64_t)sign << (f->data_w - 1)) | (exponent << f->f_w) |
         (man_rnd & (uint64_t)mask(f->f_w));
}

static uint64_t add_unpacked(const format *f, unpacked a, unpacked b) {
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
  uint64_t man_norm;
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
  uint64_t man_norm;
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
    if (ub.inf) return (uint64_t)sign << (f.data_w - 1);
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
  uint64_t man_norm;
  normalize(&f, exponent, man, 0, &exp_norm, &man_norm);
  return pack(&f, rounding_mode, 0, 1, sign, exp_norm, man_norm);
}

int ieee754_format_ok(int data_w, int exp_w) {
  int man_w = data_w - exp_w;
  return data_w <= 64 && exp_w >= 2 && exp_w <= 11 && man_w >= 6 && man_w <= 53;
}

uint64_t ieee754_from_double(double value, int data_w, int exp_w) {
  format f = make_format(data_w, exp_w);
  uint64_t raw;
  memcpy(&raw, &value, sizeof raw);

  int sign = (int)(raw >> 63);
  int exp_d = (int)(raw >> 52) & 0x7ff;
  uint64_t man = raw & (((uint64_t)1 << 52) - 1);

  if (exp_d == 0x7ff) return man ? nan_bits(&f) : inf_bits(&f, sign);
  uint64_t sign_bits = (uint64_t)sign << (f.data_w - 1);
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

  uint64_t kept = man >> shift;
  if (shift > 0) {
    uint64_t rem = man & (((uint64_t)1 << shift) - 1);
    uint64_t half = (uint64_t)1 << (shift - 1);
    if (rem > half || (rem == half && (kept & 1))) kept++;
  }

  if (exp_field < 1) {
    uint64_t min_normal = (uint64_t)1 << f.f_w;
    uint64_t field = kept >= min_normal ? (uint64_t)1 << f.f_w : 0;
    return sign_bits | field | (kept & (min_normal - 1));
  }
  if (kept >> f.man_w) {
    kept >>= 1;
    exp_field++;
  }
  if (exp_field >= (1 << f.exp_w) - 1) return inf_bits(&f, sign);
  return sign_bits | ((uint64_t)exp_field << f.f_w) | (kept & (uint64_t)mask(f.f_w));
}

double ieee754_to_double(uint64_t bits, int data_w, int exp_w) {
  format f = make_format(data_w, exp_w);
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

// Registers of the mac pipeline.
typedef struct {
  uint32_t a_lz, b_lz;
  int a_sign, b_sign;
  uint32_t a_exp, b_exp;
  uint64_t a_man, b_man;
  int valid_d1;

  int mul_sign;
  uint32_t mul_exp;
  u128 mul_man;
  int valid_d2;

  uint32_t align_exp;
  u128 align_a, align_b;
  int cin;
  int valid_d3;

  uint32_t acc_exp, acc_exp2;
  u128 acc_man, acc_man2;
  int valid_d4, valid_d5, valid_d6;

  unsigned acc_flags;
  unsigned flags_pipe[6];

  int res_sign;
  uint32_t res_exp;
  uint64_t res_man;
  int valid_o;
} mac_regs;

struct ieee754_mac {
  format f;
  int lguard_w;
  int rguard_w;
  int acc_w;
  int word_w;  // acc_w + EXTRA + 1
  uint32_t exp_zero;
  int pushed;
  int rnd;  // rounding mode at the last product
  mac_regs r;
};

ieee754_mac *ieee754_mac_new(int data_w, int exp_w, int lguard_w, int rguard_w) {
  if (!ieee754_format_ok(data_w, exp_w) || lguard_w < 0 || rguard_w < 0) return NULL;
  int acc_w = lguard_w + 1 + 2 * (data_w - exp_w) + rguard_w;
  if (acc_w + EXTRA + 1 > 128) return NULL;

  ieee754_mac *m = calloc(1, sizeof *m);
  if (!m) return NULL;
  m->f = make_format(data_w, exp_w);
  m->lguard_w = lguard_w;
  m->rguard_w = rguard_w;
  m->acc_w = acc_w;
  m->word_w = acc_w + EXTRA + 1;
  m->exp_zero = (0u - ((1u << exp_w) + 2u * (uint32_t)m->f.man_w)) & m->f.exp_mask;
  return m;
}

void ieee754_mac_free(ieee754_mac *mac) { free(mac); }

// acc_odd: the accumulator rounded to odd at acc_w + 1 bits.
static u128 mac_acc_odd(const ieee754_mac *m) {
  u128 acc = m->r.acc_man;
  return ((acc >> (EXTRA + 1)) << 1) | (u128)((acc & mask(EXTRA + 1)) != 0);
}

// Normalization of the accumulator into res_exp and res_man.
static void mac_normalize(const ieee754_mac *m, uint32_t *exp_o, uint64_t *man_o) {
  const format *f = &m->f;
  int word_w = m->word_w;
  u128 acc_man = m->r.acc_man;
  int sign = (int)(acc_man >> (word_w - 1)) & 1;
  uint32_t acc_exp = m->r.acc_exp;

  uint32_t exp_min = (0u - (uint32_t)(m->lguard_w + 2)) & f->exp_mask;
  uint32_t offset = (uint32_t)m->lguard_w + 4;
  uint32_t rshift_lim = (uint32_t)f->man_w + 2;
  uint32_t lsc = count_leading(acc_man, word_w, sign);

  uint32_t exp_diff = (exp_min - acc_exp + lsc) & f->exp_mask;
  uint32_t exp_diff2 = (exp_min - acc_exp) & f->exp_mask;
  uint32_t exp_diff2_1 = (acc_exp - exp_min) & f->exp_mask;
  uint32_t lshift = (exp_negative(f, exp_diff) ? lsc : exp_diff2_1) & f->exp_mask;
  uint32_t rshift = exp_diff2 > rshift_lim ? rshift_lim : exp_diff2;

  u128 man_norm;
  if (exp_negative(f, exp_diff2)) {
    man_norm = shift_left(acc_man, lshift) & mask(word_w);
  } else {
    u128 shifted = shift_right_signed(acc_man, word_w, rshift);
    int sticky = (shifted & 1) != 0 || (acc_man & mask((int)rshift)) != 0;
    man_norm = (shifted & ~(u128)1) | (u128)sticky;
  }

  // A zero sum takes exponent 0, as in fmac_core.v
  *exp_o = acc_man == 0 ? 0 : (acc_exp + (~lshift & f->exp_mask) + offset) & f->exp_mask;
  int low_w = word_w - f->man_w - 2;
  uint64_t top = (uint64_t)((man_norm >> low_w) & mask(f->man_w + 2));
  *man_o = (top << 1) | (uint64_t)((man_norm & mask(low_w)) != 0);
}

// One rising clock edge of the mac pipeline.
static void mac_clock(ieee754_mac *m, int valid_i, uint64_t op_a, uint64_t op_b) {
  const format *f = &m->f;
  mac_regs *r = &m->r;
  mac_regs n = *r;
  int word_w = m->word_w;

  unpacked a = unpack(f, op_a);
  unpacked b = unpack(f, op_b);

  // Stage 1
  n.a_lz = count_leading(a.man, f->man_w, 0);
  n.b_lz = count_leading(b.man, f->man_w, 0);
  n.a_sign = a.sign;
  n.b_sign = b.sign;
  n.a_exp = a.exp;
  n.b_exp = b.exp;
  n.a_man = (uint64_t)(shift_left(a.man, n.a_lz) & mask(f->man_w));
  n.b_man = (uint64_t)(shift_left(b.man, n.b_lz) & mask(f->man_w));
  n.valid_d1 = valid_i;

  // Stage 2: exact product
  int mul_zero = !(r->a_man && r->b_man);
  n.mul_sign = r->a_sign ^ r->b_sign;
  n.mul_exp = mul_zero ? m->exp_zero
                       : (r->a_exp + r->b_exp - (uint32_t)f->bias - r->a_lz - r->b_lz) & f->exp_mask;
  n.mul_man = (u128)r->a_man * r->b_man;
  n.valid_d2 = r->valid_d1;

  // Stage 3: alignment of the product or the delayed accumulator with the accumulator
  u128 product = r->mul_man;
  if (r->mul_sign) {
    product = (~product & mask(2 * f->man_w)) << (m->rguard_w + EXTRA);
    product |= mask(m->rguard_w + EXTRA);
    product |= mask(m->lguard_w + 2) << (2 * f->man_w + m->rguard_w + EXTRA);
  } else {
    product <<= m->rguard_w + EXTRA;
  }

  uint32_t a_exp_int = r->valid_d2 ? r->mul_exp : r->acc_exp2;
  u128 a_man_int = r->valid_d2 ? product : r->acc_man2;

  int acc_clr = (r->valid_d2 && !r->valid_d3) || (r->valid_d3 && !r->valid_d4);
  int acc_top = (int)(r->acc_man >> (word_w - 1)) & 1;
  int acc_top1 = (int)(r->acc_man >> (word_w - 2)) & 1;
  int acc_top2 = (int)(r->acc_man >> (word_w - 3)) & 1;
  int ovf = acc_top ^ acc_top1;
  int undf = !(acc_top1 ^ acc_top2) && r->acc_man != 0;
  u128 acc_odd = mac_acc_odd(m);

  uint32_t b_exp_int;
  u128 b_man_int;
  if (acc_clr) {
    b_exp_int = m->exp_zero;
    b_man_int = 0;
  } else if (ovf) {
    b_exp_int = (r->acc_exp + 1) & f->exp_mask;
    b_man_int = ((u128)acc_top << (word_w - 1)) | (acc_odd << (EXTRA - 1));
  } else if (undf) {
    b_exp_int = (r->acc_exp - 1) & f->exp_mask;
    b_man_int = (acc_odd & mask(m->acc_w)) << (EXTRA + 1);
  } else {
    b_exp_int = r->acc_exp;
    b_man_int = acc_odd << EXTRA;
  }

  int comp = exp_signed(f, a_exp_int) >= exp_signed(f, b_exp_int);
  uint32_t big_exp = comp ? a_exp_int : b_exp_int;
  uint32_t small_exp = comp ? b_exp_int : a_exp_int;
  u128 big_man = comp ? a_man_int : b_man_int;
  u128 small_man = comp ? b_man_int : a_man_int;

  uint32_t sticky_w = ((uint32_t)m->acc_w + EXTRA + 2) & f->exp_mask;
  uint32_t diff_exp = (big_exp - small_exp) & f->exp_mask;
  uint32_t shift = diff_exp > sticky_w ? sticky_w : diff_exp;
  u128 shifted = shift_right_signed(small_man, word_w, shift);
  int low_w = shift > (uint32_t)word_w ? word_w : (int)shift;
  int sticky = (shifted & 1) != 0 || (small_man & mask(low_w)) != 0;

  n.align_exp = big_exp;
  n.align_a = big_man;
  n.align_b = (shifted & ~(u128)1) | (u128)sticky;
  n.cin = r->valid_d2 && r->mul_sign;
  n.valid_d3 = r->valid_d2;

  // Stage 4: accumulation
  n.acc_exp = r->align_exp;
  n.acc_man = (r->align_a + r->align_b + (u128)r->cin) & mask(word_w);
  n.valid_d4 = r->valid_d3;
  n.acc_exp2 = b_exp_int;
  n.acc_man2 = b_man_int;

  // NaN, infinity and signed zero flags: a signed zero needs every term to be a zero of
  // that sign
  int term_nan = a.nan || b.nan || (a.inf && b.zero) || (a.zero && b.inf);
  int term_inf = (a.inf || b.inf) && !term_nan;
  int term_sign = a.sign ^ b.sign;
  int term_zero = (a.zero || b.zero) && !term_nan;
  unsigned term_flags = (unsigned)(term_zero && !term_sign) << 4 |
                        (unsigned)(term_zero && term_sign) << 3 | (unsigned)(term_inf && term_sign) << 2 |
                        (unsigned)(term_inf && !term_sign) << 1 | (unsigned)term_nan;
  if (valid_i) {
    unsigned merged = (r->acc_flags & term_flags & 0x18) | ((r->acc_flags | term_flags) & 7);
    n.acc_flags = r->valid_d1 ? merged : term_flags;
  }
  for (int i = 5; i > 0; i--) n.flags_pipe[i] = r->flags_pipe[i - 1];
  n.flags_pipe[0] = r->acc_flags;

  // Stage 5: normalization
  n.res_sign = acc_top;
  mac_normalize(m, &n.res_exp, &n.res_man);
  n.valid_d5 = r->valid_d4;
  n.valid_d6 = r->valid_d5;
  n.valid_o = r->valid_d6 && !r->valid_d5;

  *r = n;
}

void ieee754_mac_push(ieee754_mac *mac, uint64_t a, uint64_t b) {
  mac_clock(mac, 1, a, b);
  mac->pushed = 1;
  mac->rnd = rounding_mode;
}

uint64_t ieee754_mac_result(ieee754_mac *mac) {
  if (!mac->pushed) return 0;
  while (!mac->r.valid_o) mac_clock(mac, 0, 0, 0);

  const format *f = &mac->f;
  unsigned flags = mac->r.flags_pipe[5];
  uint64_t res;
  if (flags & 1 || (flags & 6) == 6) {
    res = nan_bits(f);
  } else if (flags & 8) {
    res = (uint64_t)1 << (f->data_w - 1);
  } else if (flags & 16) {
    res = 0;
  } else if (flags) {
    res = inf_bits(f, (flags >> 2) & 1);
  } else {
    res = pack(f, mac->rnd, mac->r.res_sign, 0, mac->r.res_sign, mac->r.res_exp, mac->r.res_man);
  }

  memset(&mac->r, 0, sizeof mac->r);
  mac->pushed = 0;
  return res;
}
