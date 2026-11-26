// The fmac pipeline, included by ieee754_model.c once per accumulator word type: W is
// 128 (unsigned __int128, formats up to binary64) or 256 (formats up to binary128). The
// word operations are w128_* and w256_*.

#define CAT_(a, b) a##b
#define CAT(a, b) CAT_(a, b)
#define word CAT(word, W)
#define wf(op) CAT(CAT(w, W), op)
#define REGS CAT(mac_regs, W)
#define FN(name) CAT(name, W)

// cls: number of leading bits equal to symbol.
static uint32_t FN(count_leading_w)(word data, int width, int symbol) {
  for (int i = width - 1; i >= 0; i--) {
    if (wf(_bit)(data, i) != symbol) return (uint32_t)(width - 1 - i);
  }
  return (uint32_t)width;
}

// Arithmetic right shift of a width-bit value.
static word FN(shift_right_signed_w)(word value, int width, uint32_t shift) {
  value = wf(_and)(value, wf(_mask)(width));
  int negative = wf(_bit)(value, width - 1);
  if (shift >= (uint32_t)width) return negative ? wf(_mask)(width) : wf(_from)(0);
  word res = wf(_shr)(value, shift);
  if (negative) res = wf(_or)(res, wf(_and)(wf(_mask)(width), wf(_not)(wf(_mask)(width - (int)shift))));
  return res;
}

// Registers of the mac pipeline.
typedef struct {
  uint32_t a_lz, b_lz;
  int a_sign, b_sign;
  uint32_t a_exp, b_exp;
  u128 a_man, b_man;
  int valid_d1;

  int mul_sign;
  uint32_t mul_exp;
  word mul_man;
  int valid_d2;

  uint32_t align_exp;
  word align_a, align_b;
  int cin;
  int valid_d3;

  uint32_t acc_exp, acc_exp2;
  word acc_man, acc_man2;
  int valid_d4, valid_d5, valid_d6;

  unsigned acc_flags;
  unsigned flags_pipe[6];

  int res_sign;
  uint32_t res_exp;
  u128 res_man;
  int valid_o;
} REGS;

// acc_fb: the accumulator rounded at acc_w + 1 bits to nearest, ties to even (the RTL), or,
// for studies, with another feedback rounding.
static word FN(mac_acc_fb)(const mac_cfg *m, const REGS *r) {
  word acc = r->acc_man;
  word kept = wf(_shr)(acc, EXTRA);
  int first = wf(_bit)(acc, EXTRA - 1);
  int rest = wf(_nz)(wf(_and)(acc, wf(_mask)(EXTRA - 1)));
  switch (m->fb) {
    case IEEE754_FB_TRUNC: return kept;
    case IEEE754_FB_FIRST: return wf(_or)(kept, wf(_from)((u128)first));
    case IEEE754_FB_NEAR_UP: return wf(_add)(kept, wf(_from)((u128)first));
    case IEEE754_FB_ODD:
      return wf(_or)(wf(_shl)(wf(_shr)(acc, EXTRA + 1), 1),
                     wf(_from)((u128)wf(_nz)(wf(_and)(acc, wf(_mask)(EXTRA + 1)))));
    default: return wf(_add)(kept, wf(_from)((u128)(first & (rest | wf(_bit)(kept, 0)))));
  }
}

// Normalization of the accumulator into res_exp and res_man.
static void FN(mac_normalize)(const mac_cfg *m, const REGS *r, uint32_t *exp_o, u128 *man_o) {
  const format *f = &m->f;
  const format *ae = &m->af;  // accumulator exponents
  int word_w = m->word_w;
  word acc_man = r->acc_man;
  int sign = wf(_bit)(acc_man, word_w - 1);
  uint32_t acc_exp = r->acc_exp;

  uint32_t exp_min = (0u - (uint32_t)(m->lguard_w + 2)) & ae->exp_mask;
  uint32_t offset = (uint32_t)m->lguard_w + 4;
  uint32_t rshift_lim = (uint32_t)f->man_w + 2;
  uint32_t lsc = FN(count_leading_w)(acc_man, word_w, sign);

  uint32_t exp_diff = (exp_min - acc_exp + lsc) & ae->exp_mask;
  uint32_t exp_diff2 = (exp_min - acc_exp) & ae->exp_mask;
  uint32_t exp_diff2_1 = (acc_exp - exp_min) & ae->exp_mask;
  uint32_t lshift = (exp_negative(ae, exp_diff) ? lsc : exp_diff2_1) & ae->exp_mask;
  uint32_t rshift = exp_diff2 > rshift_lim ? rshift_lim : exp_diff2;

  word man_norm;
  if (exp_negative(ae, exp_diff2)) {
    man_norm = wf(_and)(wf(_shl)(acc_man, lshift), wf(_mask)(word_w));
  } else {
    word shifted = FN(shift_right_signed_w)(acc_man, word_w, rshift);
    int sticky = wf(_bit)(shifted, 0) || wf(_nz)(wf(_and)(acc_man, wf(_mask)((int)rshift)));
    man_norm = wf(_or)(wf(_and)(shifted, wf(_not)(wf(_from)(1))), wf(_from)((u128)sticky));
  }

  uint32_t e = (acc_exp + (~lshift & ae->exp_mask) + offset) & ae->exp_mask;
  // with a wider accumulator exponent, from 2**(exp_w+1)-1 up the result's exponent
  // saturates at 2**(exp_w+1)-2, an overflow for pack (fmac_core1.v)
  uint32_t exp_top = (1u << (f->exp_w + 1)) - 1;
  *exp_o = (ae->exp_w > f->exp_w && (e >> (f->exp_w + 1) || (e & exp_top) == exp_top)) ? exp_top - 1 : e;
  int low_w = word_w - f->man_w - 2;
  u128 top = wf(_lo)(wf(_and)(wf(_shr)(man_norm, (uint32_t)low_w), wf(_mask)(f->man_w + 2)));
  *man_o = (top << 1) | (u128)wf(_nz)(wf(_and)(man_norm, wf(_mask)(low_w)));
}

// The product's magnitude in the adder word: the 2p-bit product above rguard_w + EXTRA
// low bits, with lguard_w + 2 zero bits above it. A negative product is negated in the
// alignment (mac_align).
static word FN(mac_product)(const mac_cfg *m, word man) {
  return wf(_shl)(man, (uint32_t)(m->rguard_w + EXTRA));
}

// The accumulator fed back: rounded, then shifted by at most one bit right or up to step
// bits left, or cleared at the start of a stream. prod: a product is being accumulated
// (statistics).
static void FN(mac_feedback)(mac_cfg *m, const REGS *r, int clr, int prod, uint32_t *exp_o, word *man_o) {
  const format *ae = &m->af;  // accumulator exponents
  int word_w = m->word_w;
  int acc_top = wf(_bit)(r->acc_man, word_w - 1);
  int acc_top1 = wf(_bit)(r->acc_man, word_w - 2);
  int acc_top2 = wf(_bit)(r->acc_man, word_w - 3);
  int ovf = acc_top ^ acc_top1;
  int undf = !(acc_top1 ^ acc_top2) && wf(_nz)(r->acc_man);
  word acc_fb = FN(mac_acc_fb)(m, r);
  if (clr) {
    *exp_o = m->exp_zero;
    *man_o = wf(_from)(0);
  } else if (ovf) {
    *exp_o = (r->acc_exp + 1) & ae->exp_mask;
    *man_o = wf(_or)(wf(_shl)(wf(_from)((u128)acc_top), (uint32_t)(word_w - 1)), wf(_shl)(acc_fb, EXTRA - 1));
  } else if (undf) {
    // shift left by up to step positions, keeping two sign bits
    uint32_t lsc = FN(count_leading_w)(r->acc_man, word_w, acc_top);
    uint32_t sh = lsc - 2 < (uint32_t)m->step ? lsc - 2 : (uint32_t)m->step;
    if (prod && lsc - 2 > sh) {
      m->stat_lagged++;
      m->stat_lag_bits += lsc - 2 - sh;
    }
    *exp_o = (r->acc_exp - sh) & ae->exp_mask;
    *man_o = wf(_and)(wf(_shl)(acc_fb, EXTRA + sh), wf(_mask)(word_w));
  } else {
    *exp_o = r->acc_exp;
    *man_o = wf(_shl)(acc_fb, EXTRA);
  }
}

// Alignment of two addends: the larger exponent, its addend, and the other shifted right
// with a sticky bit. a_neg: a is the magnitude of a negative product, negated here as its
// one's complement plus the adder's carry-in (a_neg): before the shift when it is the
// larger addend, after the shift (sticky bit included) when it is the smaller one, so
// that the carry-in always lands on its least significant bit.
static void FN(mac_align)(const mac_cfg *m, uint32_t a_exp, word a_man, int a_neg, uint32_t b_exp, word b_man,
                          uint32_t *exp_o, word *big_o, word *small_o) {
  const format *ae = &m->af;  // accumulator exponents
  int word_w = m->word_w;
  int comp = exp_signed(ae, a_exp) >= exp_signed(ae, b_exp);
  uint32_t small_exp = comp ? b_exp : a_exp;
  word small_man = comp ? b_man : a_man;
  word ones = wf(_mask)(word_w);
  *exp_o = comp ? a_exp : b_exp;
  *big_o = comp ? (a_neg ? wf(_and)(wf(_not)(a_man), ones) : a_man) : b_man;
  uint32_t sticky_w = ((uint32_t)m->acc_w + EXTRA + 2) & ae->exp_mask;
  uint32_t diff_exp = (*exp_o - small_exp) & ae->exp_mask;
  uint32_t shift = diff_exp > sticky_w ? sticky_w : diff_exp;
  word shifted = FN(shift_right_signed_w)(small_man, word_w, shift);
  int low_w = shift > (uint32_t)word_w ? word_w : (int)shift;
  int sticky = wf(_bit)(shifted, 0) || wf(_nz)(wf(_and)(small_man, wf(_mask)(low_w)));
  *small_o = wf(_or)(wf(_and)(shifted, wf(_not)(wf(_from)(1))), wf(_from)((u128)sticky));
  if (!comp && a_neg) *small_o = wf(_and)(wf(_not)(*small_o), ones);
}

// The special-case flags of a stream after a term: NaN, infinity and signed zero; a signed
// zero needs every term to be a zero of that sign.
static unsigned FN(mac_flags)(const REGS *r, int valid_i, unpacked a, unpacked b) {
  int term_nan = a.nan || b.nan || (a.inf && b.zero) || (a.zero && b.inf);
  int term_inf = (a.inf || b.inf) && !term_nan;
  int term_sign = a.sign ^ b.sign;
  int term_zero = (a.zero || b.zero) && !term_nan;
  unsigned term_flags = (unsigned)(term_zero && !term_sign) << 4 |
                        (unsigned)(term_zero && term_sign) << 3 | (unsigned)(term_inf && term_sign) << 2 |
                        (unsigned)(term_inf && !term_sign) << 1 | (unsigned)term_nan;
  if (!valid_i) return r->acc_flags;
  unsigned merged = (r->acc_flags & term_flags & 0x18) | ((r->acc_flags | term_flags) & 7);
  return r->valid_d1 ? merged : term_flags;
}

// One rising clock edge of the pipelined mac (fmac_core.v): a feedback loop of two stages
// (alignment, addition) with two interleaved accumulators.
static void FN(mac_clock2)(mac_cfg *m, REGS *r, int valid_i, u128 op_a, u128 op_b) {
  const format *f = &m->f;
  const format *ae = &m->af;  // accumulator exponents
  REGS n = *r;
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
  n.a_man = shift_left(a.man, n.a_lz) & mask(f->man_w);
  n.b_man = shift_left(b.man, n.b_lz) & mask(f->man_w);
  n.valid_d1 = valid_i;

  // Stage 2: exact product
  int mul_zero = !(r->a_man && r->b_man);
  n.mul_sign = r->a_sign ^ r->b_sign;
  n.mul_exp = mul_zero ? m->exp_zero
                       : (r->a_exp + r->b_exp - (uint32_t)f->bias - r->a_lz - r->b_lz) & ae->exp_mask;
  n.mul_man = wf(_mul)(r->a_man, r->b_man);
  n.valid_d2 = r->valid_d1;

  // Stage 3: alignment of the product or the delayed accumulator with the accumulator
  word product = FN(mac_product)(m, r->mul_man);
  uint32_t a_exp_int = r->valid_d2 ? r->mul_exp : r->acc_exp2;
  word a_man_int = r->valid_d2 ? product : r->acc_man2;

  int acc_clr = (r->valid_d2 && !r->valid_d3) || (r->valid_d3 && !r->valid_d4);
  uint32_t b_exp_int;
  word b_man_int;
  FN(mac_feedback)(m, r, acc_clr, r->valid_d2, &b_exp_int, &b_man_int);
  if (r->valid_d2) m->stat_accs++;
  FN(mac_align)(m, a_exp_int, a_man_int, r->valid_d2 && r->mul_sign, b_exp_int, b_man_int, &n.align_exp,
                &n.align_a, &n.align_b);
  n.cin = r->valid_d2 && r->mul_sign;
  n.valid_d3 = r->valid_d2;

  // Stage 4: accumulation
  n.acc_exp = r->align_exp;
  n.acc_man = wf(_and)(wf(_add)(wf(_add)(r->align_a, r->align_b), wf(_from)((u128)r->cin)), wf(_mask)(word_w));
  n.valid_d4 = r->valid_d3;
  n.acc_exp2 = b_exp_int;
  n.acc_man2 = b_man_int;

  n.acc_flags = FN(mac_flags)(r, valid_i, a, b);
  for (int i = 5; i > 0; i--) n.flags_pipe[i] = r->flags_pipe[i - 1];
  n.flags_pipe[0] = r->acc_flags;

  // Stage 5: normalization
  n.res_sign = wf(_bit)(r->acc_man, word_w - 1);
  FN(mac_normalize)(m, r, &n.res_exp, &n.res_man);
  n.valid_d5 = r->valid_d4;
  n.valid_d6 = r->valid_d5;
  n.valid_o = r->valid_d6 && !r->valid_d5;

  *r = n;
}

// One rising clock edge of the small-format mac (fmac_core1.v): the product, alignment and
// addition in one cycle into a single accumulator; at the end of a stream the result is
// normalized from it into the output register.
static void FN(mac_clock1)(mac_cfg *m, REGS *r, int valid_i, u128 op_a, u128 op_b) {
  const format *f = &m->f;
  const format *ae = &m->af;  // accumulator exponents
  REGS n = *r;
  int word_w = m->word_w;

  unpacked a = unpack(f, op_a);
  unpacked b = unpack(f, op_b);
  if (valid_i) {
    uint32_t a_lz = count_leading(a.man, f->man_w, 0);
    uint32_t b_lz = count_leading(b.man, f->man_w, 0);
    u128 a_man = shift_left(a.man, a_lz) & mask(f->man_w);
    u128 b_man = shift_left(b.man, b_lz) & mask(f->man_w);
    int mul_sign = a.sign ^ b.sign;
    uint32_t mul_exp = !(a_man && b_man) ? m->exp_zero
                                         : (a.exp + b.exp - (uint32_t)f->bias - a_lz - b_lz) & ae->exp_mask;
    word product = FN(mac_product)(m, wf(_mul)(a_man, b_man));
    uint32_t b_exp_int;
    word b_man_int;
    FN(mac_feedback)(m, r, !r->valid_d1, 1, &b_exp_int, &b_man_int);
    m->stat_accs++;
    word big, small;
    FN(mac_align)(m, mul_exp, product, mul_sign, b_exp_int, b_man_int, &n.acc_exp, &big, &small);
    n.acc_man = wf(_and)(wf(_add)(wf(_add)(big, small), wf(_from)((u128)mul_sign)), wf(_mask)(word_w));
  }
  n.acc_flags = FN(mac_flags)(r, valid_i, a, b);
  n.valid_d1 = valid_i;

  // end of a stream: the result into the output register
  n.valid_o = r->valid_d1 && !valid_i;
  n.res_sign = wf(_bit)(r->acc_man, word_w - 1);
  FN(mac_normalize)(m, r, &n.res_exp, &n.res_man);
  n.flags_pipe[5] = r->acc_flags;

  *r = n;
}

static void FN(mac_clock)(mac_cfg *m, REGS *r, int valid_i, u128 op_a, u128 op_b) {
  if (m->loop1)
    FN(mac_clock1)(m, r, valid_i, op_a, op_b);
  else
    FN(mac_clock2)(m, r, valid_i, op_a, op_b);
}

// Ends the stream: clocks the pipeline until the result is out, rounds it in mode rnd and
// clears the registers.
static u128 FN(mac_finish)(mac_cfg *m, REGS *r, int rnd) {
  while (!r->valid_o) FN(mac_clock)(m, r, 0, 0, 0);
  const format *f = &m->f;
  unsigned flags = r->flags_pipe[5];
  u128 res;
  if (flags & 1 || (flags & 6) == 6) {
    res = nan_bits(f);
  } else if (flags & 8) {
    res = (u128)1 << (f->data_w - 1);
  } else if (flags & 16) {
    res = 0;
  } else if (flags) {
    res = inf_bits(f, (flags >> 2) & 1);
  } else {
    res = pack(f, rnd, r->res_sign, 0, r->res_sign, r->res_exp, r->res_man);
  }
  memset(r, 0, sizeof *r);
  return res;
}

#undef word
#undef wf
#undef REGS
#undef FN
