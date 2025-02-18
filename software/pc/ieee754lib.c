#include <stdio.h>
#include <stdint.h>
#include <math.h>

#include "ieee754lib.h"

#define MSB(w) ((int64_t)1 << ((w) - 1))
#define MASK(width) (((int64_t)1 << (width)) - 1)

#define LSHIFT(num, shift) ({\
  uint64_t num_ = num;\
  if ((shift) < 64) num_ <<= (shift);\
  else num_ = 0;\
  num_;\
})

#define RSHIFT(num, shift) ({\
  uint64_t num_ = num;\
  if ((shift) < 64) num_ >>= (shift);\
  else num_ = 0;\
  num_;\
})

#define SRSHIFT(num, shift) ({\
  int64_t num_ = num;\
  if ((shift) < 64) num_ >>= (shift);\
  else if (num_ < 0) num_ = -1;\
  else num_ = 0;\
  num_;\
})

#define cls(num, width, symbol) ({\
  uint64_t num_ = num;\
  int32_t leadings_ = width;\
  uint64_t symbol_ = symbol? 0: 1;\
  uint64_t mask_ = 1;\
\
  int32_t i;\
  for (i = 0; i < (width); i++) {\
    if ((num_ & mask_) == symbol_)\
      leadings_ = (width) - i - 1;\
    num_ >>= 1;\
  }\
\
  leadings_;\
})

#define clz(num, width) cls(num, width, 0)

ieee754Unpacked last_res_upk;

ieee754Unpacked ieee754_unpack_(ieee754 input, int32_t dw, int32_t ew) {
  ieee754Unpacked upk;
  upk.sign = (input >> (dw - 1)) & 1;
  upk.exp  = (input >> (dw - 1 - ew)) & MASK(ew);
  upk.man  = input & MASK(IEEE754_F_W(dw, ew));

  uint8_t sub = upk.exp? 0: 1;
  if (sub) {
    upk.exp++;
  } else {
    upk.man |= (uint64_t)1 << IEEE754_F_W(dw, ew);
  }

  return upk;
}

ieee754Unpacked ieee754_add_sub(ieee754Unpacked a, ieee754Unpacked b, uint8_t op, int32_t dw, int32_t ew) {
  ieee754Unpacked o;

  b.sign ^= op;

  uint8_t sign_a, sign_b;
  int32_t exp_a, exp_b;
  uint64_t sig_a, sig_b;
  if (a.exp >= b.exp) {
    sign_a = a.sign;
    exp_a = a.exp;
    sig_a = a.man << 3;

    sign_b = b.sign;
    exp_b = b.exp;
    sig_b = b.man << 3;
  } else {
    sign_a = b.sign;
    exp_a = b.exp;
    sig_a = b.man << 3;

    sign_b = a.sign;
    exp_b = a.exp;
    sig_b = a.man << 3;
  }

  int32_t diff_exp = exp_a - exp_b;
  int8_t sticky = (sig_b & MASK(diff_exp + 1))? 1 : 0;
  sig_b = RSHIFT(sig_b, diff_exp);
  sig_b |= sticky;

  uint8_t subtract = sign_a ^ sign_b;
  if (subtract) {
    sig_a = -sig_a;
  }

  uint64_t sig = sig_a + sig_b;

  uint8_t sig_msb  = (sig >> (IEEE754_RES_W(dw, ew) + 1)) & 1;
  o.sign = subtract? (sign_a ^ 1) ^ sig_msb: sign_a;
  if (subtract & sig_msb) {
    sig = -sig;
  }

  last_res_upk.sign = o.sign;
  last_res_upk.exp = exp_a;
  last_res_upk.man = sig << (IEEE754_MAN_W(dw, ew) - 4);

  if (exp_a <= IEEE754_EXP_MAX(ew)) {
    if (sig) {
      int32_t leadings = clz(sig, IEEE754_RES_W(dw, ew)+1);
      if ((exp_a - leadings + 1) < IEEE754_EXP_MIN) {
        leadings = exp_a - IEEE754_EXP_MIN + 1;
      }
      o.exp = exp_a - leadings + 1;
      o.man = sig << leadings;
      sticky |= o.man & 1;
      o.man = (o.man >> 1) | sticky;
    } else {
      o.sign = 0;
      o.exp  = IEEE754_EXP_MIN;
      o.man  = 0;
    }
  }

  if (o.exp > IEEE754_EXP_MAX(ew)) {
    o.exp = IEEE754_EXP_MAX(ew);
    o.man = 1 << (IEEE754_F_W(dw, ew) + 3);
  }

  return o;
}

ieee754Unpacked ieee754_mul_(ieee754Unpacked a, ieee754Unpacked b, int32_t dw, int32_t ew) {
  ieee754Unpacked o;

  o.sign = a.sign ^ b.sign;

  uint64_t sig = a.man * b.man;

  int32_t exp = sig? a.exp + b.exp - IEEE754_BIAS(ew): IEEE754_EXP_MIN;

  last_res_upk.sign = o.sign;
  last_res_upk.exp = exp;
  last_res_upk.man = sig;

  int32_t shift = IEEE754_MAN_W(dw, ew) - 3;
  int32_t lds = clz(sig, (IEEE754_MAN_W(dw, ew) << 1));
  if ((exp - lds + 1) < IEEE754_EXP_MIN) {
    lds = exp - IEEE754_EXP_MIN + 1;
  }
  exp -= lds - 1;
  shift -= lds;

  int8_t sticky = 0;
  if (shift < 0) {
    sig = LSHIFT(sig, -shift);
  } else {
    sticky = (sig & MASK(shift + 1))? 1 : 0;
    sig = RSHIFT(sig, shift);
    sig |= sticky;
  }

  if (exp <= IEEE754_EXP_MAX(ew) && exp > IEEE754_EXP_MIN) {
    if (sig) {
      int32_t leadings = clz(sig, IEEE754_RES_W(dw, ew));
      if ((exp - leadings) < IEEE754_EXP_MIN) {
        leadings = exp - IEEE754_EXP_MIN;
      }
      o.exp = exp - leadings;
      o.man = sig << leadings;
    } else {
      o.sign = 0;
      o.exp  = IEEE754_EXP_MIN;
      o.man  = 0;
    }
  } else {
    o.exp = exp;
    o.man = sig;
  }

  if (o.exp > IEEE754_EXP_MAX(ew)) {
    o.exp = IEEE754_EXP_MAX(ew);
    o.man = 1 << (IEEE754_F_W(dw, ew) + 3);
  } else if (o.exp < IEEE754_EXP_MIN - IEEE754_MAN_W(dw, ew)) {
    o.sign = 0;
    o.exp  = IEEE754_EXP_MIN;
    o.man  = 0;
  }

  if (o.exp < IEEE754_EXP_MIN) {
    shift = IEEE754_EXP_MIN - o.exp;
    o.exp = IEEE754_EXP_MIN;
    sticky = (o.man & MASK(shift + 1))? 1 : 0;
    o.man = RSHIFT(o.man, shift) | sticky;
  }

  return o;
}

ieee754Unpacked ieee754_div_(ieee754Unpacked a, ieee754Unpacked b, int32_t dw, int32_t ew) {
  ieee754Unpacked o = {};

  if (!b.man) {
    o.sign = 0;
    o.exp = IEEE754_EXP_NAN(ew);
    o.man = 3 << (IEEE754_RES_W(dw, ew) - 2);
    return o;
  }

  uint64_t dividend = a.man;
  dividend <<= IEEE754_MAN_W(dw, ew);

  uint64_t divisor = b.man;

  o.sign = a.sign ^ b.sign;
  int32_t exp = a.man? a.exp - b.exp + IEEE754_BIAS(ew): IEEE754_EXP_MIN;

  int32_t i, bit;
  uint64_t quotient = 0, remainder = 0;
  for (i = 0; i < (IEEE754_MAN_W(dw, ew) << 1); i++) {
    if (dividend & MSB(IEEE754_MAN_W(dw, ew) << 1)) {
      bit = 1;
    } else {
      bit = 0;
    }

    quotient <<= 1;
    remainder <<= 1;
    remainder |= bit;
    dividend <<= 1;

    if (remainder >= divisor) {
      quotient |= 1;
      remainder -= divisor;
    }
  }
  int8_t sticky = remainder? 1: 0;
  quotient |= sticky;

  last_res_upk.sign = o.sign;
  last_res_upk.exp = exp;
  last_res_upk.man = quotient << (IEEE754_MAN_W(dw, ew) - 2);

  int32_t shift = IEEE754_MAN_W(dw, ew) - 3;
  int32_t lds = clz(quotient, (IEEE754_MAN_W(dw, ew) << 1));
  if ((exp - lds + IEEE754_MAN_W(dw, ew) - 1) < IEEE754_EXP_MIN) {
    lds = exp - IEEE754_EXP_MIN + IEEE754_MAN_W(dw, ew) - 1;
  }
  exp -= lds - IEEE754_MAN_W(dw, ew) + 1;
  shift -= lds;

  uint64_t sig;
  if (shift > 0) {
    sticky |= (quotient & MASK(shift + 1))? 1 : 0;
    sig = RSHIFT(quotient, shift);
    sig |= sticky;
  } else {
    sig = quotient << -shift;
  }

  if (exp <= IEEE754_EXP_MAX(ew) && exp > IEEE754_EXP_MIN) {
    if (sig) {
      int32_t leadings = clz(sig, IEEE754_RES_W(dw, ew));
      if ((exp - leadings) < IEEE754_EXP_MIN) {
        leadings = exp - IEEE754_EXP_MIN;
      }
      o.exp = exp - leadings;
      o.man = sig << leadings;
    } else {
      o.sign = 0;
      o.exp  = IEEE754_EXP_MIN;
      o.man  = 0;
    }
  } else {
    o.exp = exp;
    o.man = sig;
  }

  if (o.exp > IEEE754_EXP_MAX(ew)) {
    o.exp = IEEE754_EXP_MAX(ew);
    o.man = 1 << (IEEE754_F_W(dw, ew) + 3);
  } else if (exp < IEEE754_EXP_MIN - IEEE754_MAN_W(dw, ew)) { // SIG_MAX_W -> SIG_MIN_W
    o.sign = 0;
    o.exp  = IEEE754_EXP_MIN;
    o.man  = 0;
  }

  if (o.exp < IEEE754_EXP_MIN) {
    shift = IEEE754_EXP_MIN - o.exp;
    o.exp = IEEE754_EXP_MIN;
    sticky = (o.man & MASK(shift + 1))? 1 : 0;
    o.man = RSHIFT(o.man, shift) | sticky;
  }

  return o;
}

#define RGUARD_W 0

ieee754Unpacked ieee754_mac_(ieee754 *vec_a, ieee754 *vec_b, uint16_t n, int32_t dw, int32_t ew) {
  ieee754Unpacked o;

  int32_t acc_exp = IEEE754_EXP_MIN;
  int64_t acc_sig = 0;
  uint16_t i;
  for (i = 0; i < n; i++) {
    ieee754Unpacked a = ieee754_unpack_(vec_a[i], dw, ew);
    ieee754Unpacked b = ieee754_unpack_(vec_b[i], dw, ew);

    uint8_t mul_sign = a.sign ^ b.sign;
    uint64_t mul_sig = a.man * b.man;
    int32_t mul_exp = mul_sig? a.exp + b.exp - IEEE754_BIAS(ew) : IEEE754_EXP_MIN;

    if (mul_sign) {
      mul_sig = -mul_sig;
    }

    uint8_t acc_sig_msb  = acc_sig >> ((IEEE754_MAN_W(dw, ew) << 1) + 2 + RGUARD_W); // 2 for sign and carry
    uint8_t acc_sig_msb2 = acc_sig >> ((IEEE754_MAN_W(dw, ew) << 1) + 1 + RGUARD_W);
    uint8_t acc_sig_msb3 = acc_sig >> ((IEEE754_MAN_W(dw, ew) << 1) + RGUARD_W);
    if (acc_sig_msb != acc_sig_msb2) {
      acc_exp++;
      acc_sig >>= 1;
    } else if (acc_sig_msb2 == acc_sig_msb3) {
      acc_exp--;
      acc_sig <<= 1;
    }

    int32_t exp_a, exp_b;
    int64_t sig_a, sig_b;
    if (mul_exp >= acc_exp) {
      exp_a = mul_exp;
      sig_a = mul_sig << RGUARD_W;

      exp_b = acc_exp;
      sig_b = acc_sig;
    } else {
      exp_a = acc_exp;
      sig_a = acc_sig;

      exp_b = mul_exp;
      sig_b = mul_sig << RGUARD_W;
    }
    acc_exp = exp_a;

    int32_t diff_exp = exp_a - exp_b;

    uint8_t sig_lsb    = (sig_b & (1 << diff_exp))? 1: 0;
    uint8_t guard_bit  = (sig_b & (1 << (diff_exp - 1)))? 1: 0;
    uint8_t round_bit  = (sig_b & (1 << (diff_exp - 2)))? 1: 0;
    uint8_t sticky_bit = (sig_b & ((1 << (diff_exp - 2)) - 1))? 1: 0;

    uint8_t round = guard_bit & (sig_lsb | round_bit | sticky_bit);

    sig_b = SRSHIFT(sig_b, diff_exp);

    acc_sig = sig_a + sig_b + round;
  }

  o.sign = 0;
  if (acc_sig < 0) {
    o.sign = 1;
    acc_sig = -acc_sig;
  }

  int32_t shift = IEEE754_MAN_W(dw, ew) + RGUARD_W - 1;
  int32_t lds = clz(acc_sig, ((IEEE754_MAN_W(dw, ew) << 1) + 2 + RGUARD_W));
  if ((acc_exp - lds + 3) < IEEE754_EXP_MIN) {
    lds = acc_exp - IEEE754_EXP_MIN + 3;
  }
  acc_exp -= lds - 3;
  shift -= lds;

  int8_t sticky = 0;
  if (shift < 0) {
     acc_sig= LSHIFT(acc_sig, -shift);
  } else {
    sticky = (acc_sig & MASK(shift + 1))? 1 : 0;
    acc_sig = RSHIFT(acc_sig, shift);
    acc_sig |= sticky;
  }

  if (acc_exp <= IEEE754_EXP_MAX(ew) && acc_exp > IEEE754_EXP_MIN) {
    if (acc_sig) {
      int32_t leadings = clz(acc_sig, IEEE754_RES_W(dw, ew));
      if ((acc_exp - leadings) < IEEE754_EXP_MIN) {
        leadings = acc_exp - IEEE754_EXP_MIN;
      }
      o.exp = acc_exp - leadings;
      o.man = acc_sig << leadings;
    } else {
      o.sign = 0;
      o.exp  = IEEE754_EXP_MIN;
      o.man  = 0;
    }
  } else {
    o.exp = acc_exp;
    o.man = acc_sig;
  }

  if (o.exp > IEEE754_EXP_MAX(ew)) {
    o.exp = IEEE754_EXP_MAX(ew);
    o.man = 1 << (IEEE754_F_W(dw, ew) + 3);
  } else if (o.exp < IEEE754_EXP_MIN - IEEE754_MAN_W(dw, ew)) {
    o.sign = 0;
    o.exp  = IEEE754_EXP_MIN;
    o.man  = 0;
  }

  if (o.exp < IEEE754_EXP_MIN) {
    shift = IEEE754_EXP_MIN - o.exp;
    o.exp = IEEE754_EXP_MIN;
    sticky = (o.man & MASK(shift + 1))? 1 : 0;
    o.man = RSHIFT(o.man, shift) | sticky;
  }

  return o;
}

ieee754Unpacked ieee754_acc_(ieee754Acc * acc, ieee754Unpacked *a, int32_t dw, int32_t ew) {
  ieee754Unpacked o;

  if (a) {
    last_res_upk.sign = a->sign;
    last_res_upk.exp  = a->exp;
    last_res_upk.man  = a->man << (IEEE754_MAN_W(dw, ew) - 1);
  }

  int32_t acc_exp = acc->exp;
  int64_t acc_sig = acc->man;

  if (last_res_upk.sign) {
    last_res_upk.man = -last_res_upk.man;
  }

  uint8_t acc_sig_msb  = acc_sig >> ((IEEE754_MAN_W(dw, ew) << 1) + 2 + RGUARD_W); // 2 for sign and carry
  uint8_t acc_sig_msb2 = acc_sig >> ((IEEE754_MAN_W(dw, ew) << 1) + 1 + RGUARD_W);
  uint8_t acc_sig_msb3 = acc_sig >> ((IEEE754_MAN_W(dw, ew) << 1) + RGUARD_W);
  if (acc_sig_msb != acc_sig_msb2) {
    acc_exp++;
    acc_sig >>= 1;
  } else if (acc_sig_msb2 == acc_sig_msb3) {
    acc_exp--;
    acc_sig <<= 1;
  }

  int32_t exp_a, exp_b;
  int64_t sig_a, sig_b;
  if (last_res_upk.exp >= acc_exp) {
    exp_a = last_res_upk.exp;
    sig_a = last_res_upk.man << RGUARD_W;

    exp_b = acc_exp;
    sig_b = acc_sig;
  } else {
    exp_a = acc_exp;
    sig_a = acc_sig;

    exp_b = last_res_upk.exp;
    sig_b = last_res_upk.man << RGUARD_W;
  }
  acc_exp = exp_a;

  int32_t diff_exp = exp_a - exp_b;

  uint8_t sig_lsb    = (sig_b & (1 << diff_exp))? 1: 0;
  uint8_t guard_bit  = (sig_b & (1 << (diff_exp - 1)))? 1: 0;
  uint8_t round_bit  = (sig_b & (1 << (diff_exp - 2)))? 1: 0;
  uint8_t sticky_bit = (sig_b & ((1 << (diff_exp - 2)) - 1))? 1: 0;

  uint8_t round = guard_bit & (sig_lsb | round_bit | sticky_bit);

  sig_b = SRSHIFT(sig_b, diff_exp);

  acc_sig = sig_a + sig_b + round;

  acc->exp = acc_exp;
  acc->man = acc_sig;

  o.sign = 0;
  if (acc_sig < 0) {
    o.sign = 1;
    acc_sig = -acc_sig;
  }

  int32_t shift = IEEE754_MAN_W(dw, ew) + RGUARD_W - 1;
  int32_t lds = clz(acc_sig, ((IEEE754_MAN_W(dw, ew) << 1) + 2 + RGUARD_W));
  if ((acc_exp - lds + 3) < IEEE754_EXP_MIN) {
    lds = acc_exp - IEEE754_EXP_MIN + 3;
  }
  acc_exp -= lds - 3;
  shift -= lds;

  int8_t sticky = 0;
  if (shift < 0) {
     acc_sig= LSHIFT(acc_sig, -shift);
  } else {
    sticky = (acc_sig & MASK(shift + 1))? 1 : 0;
    acc_sig = RSHIFT(acc_sig, shift);
    acc_sig |= sticky;
  }

  if (acc_exp <= IEEE754_EXP_MAX(ew) && acc_exp > IEEE754_EXP_MIN) {
    if (acc_sig) {
      int32_t leadings = clz(acc_sig, IEEE754_RES_W(dw, ew));
      if ((acc_exp - leadings) < IEEE754_EXP_MIN) {
        leadings = acc_exp - IEEE754_EXP_MIN;
      }
      o.exp = acc_exp - leadings;
      o.man = acc_sig << leadings;
    } else {
      o.sign = 0;
      o.exp  = IEEE754_EXP_MIN;
      o.man  = 0;
    }
  } else {
    o.exp = acc_exp;
    o.man = acc_sig;
  }

  if (o.exp > IEEE754_EXP_MAX(ew)) {
    o.exp = IEEE754_EXP_MAX(ew);
    o.man = 1 << (IEEE754_F_W(dw, ew) + 3);
  } else if (o.exp < IEEE754_EXP_MIN - IEEE754_MAN_W(dw, ew)) {
    o.sign = 0;
    o.exp  = IEEE754_EXP_MIN;
    o.man  = 0;
  }

  if (o.exp < IEEE754_EXP_MIN) {
    shift = IEEE754_EXP_MIN - o.exp;
    o.exp = IEEE754_EXP_MIN;
    sticky = (o.man & MASK(shift + 1))? 1 : 0;
    o.man = RSHIFT(o.man, shift) | sticky;
  }

  return o;
}

ieee754 ieee754_pack_(ieee754Unpacked o, int32_t dw, int32_t ew) {
  int32_t packed;

  int32_t exp = o.exp;

  uint64_t man = o.man >> 3;

  uint8_t man_lsb    = (o.man >> 3) & 1;
  uint8_t guard_bit  = (o.man >> 2) & 1;
  uint8_t round_bit  = (o.man >> 1) & 1;
  uint8_t sticky_bit = o.man & 1;

  if (guard_bit & (man_lsb | round_bit | sticky_bit)) {
    man++;
    if (man & MSB(IEEE754_MAN_W(dw, ew)+1)) {
      exp++;
      man >>= 1;
    }

    if (exp > IEEE754_EXP_MAX(ew)) {
      exp = -1;
      man = 0;
    }
  }

  uint8_t man_msb = man >> IEEE754_F_W(dw, ew);
  if (!man_msb) {
    exp--;
  }

  packed = 0;
  if (o.sign) {
    packed--;
  }
  packed = (packed << ew) | (exp & MASK(ew));
  packed = (packed << IEEE754_F_W(dw, ew)) | (man & MASK(IEEE754_F_W(dw, ew)));

  return packed;
}

ieee754 doubletoieee754_(double input, int32_t dw, int32_t ew) {
  union {
    double   d;
    uint64_t i;
  } conv = { .d = input };
  ieee754Unpacked upk;
  int32_t shift = 0;

  // Fields extraction
  uint32_t sign = conv.i >> (IEEE754_DP_DATA_W - 1);
  int32_t  exp  = (conv.i << 1) >> (IEEE754_DP_DATA_W - IEEE754_DP_EXP_W);
  uint64_t man  = (conv.i << (1 + IEEE754_DP_EXP_W)) >> (IEEE754_DP_DATA_W - IEEE754_DP_F_W);

  if (!exp) { // Denormalized or Zero
    if (!man) {
      exp = IEEE754_EXP_MIN;
    } else {
      int32_t leadings = clz(man, IEEE754_DP_MAN_W);
      shift = IEEE754_DP_MAN_W - IEEE754_RES_W(dw, ew) - leadings;

      exp += -IEEE754_DP_BIAS - leadings + 1;
    }
  } else if (exp == MASK(IEEE754_DP_EXP_W)) { // Infinity or NAN
    exp = IEEE754_EXP_NAN(ew);
    if (man) {
      man = (uint64_t)1 << (IEEE754_DP_F_W - 1);
    }
    man |= MSB(IEEE754_DP_MAN_W);

    shift = IEEE754_DP_MAN_W - IEEE754_RES_W(dw, ew);
  } else { // Normalized
    man |= MSB(IEEE754_DP_MAN_W);
    exp += -IEEE754_DP_BIAS + IEEE754_BIAS(ew);

    shift = IEEE754_DP_MAN_W - IEEE754_RES_W(dw, ew);
  }

  if (exp < IEEE754_EXP_MIN) {
    shift += IEEE754_EXP_MIN - exp;
    exp = IEEE754_EXP_MIN;
    if (shift > IEEE754_DP_F_W) {
      shift = IEEE754_DP_F_W + 1;
    }
    if (shift < -IEEE754_DP_F_W) {
      shift = -64;
    }
  }

  int8_t sticky = 0;
  if (shift < 0) {
    man = LSHIFT(man, -shift);
  } else {
    sticky = (man & MASK(shift + 1))? 1 : 0;
    man = RSHIFT(man, shift) | sticky;
  }

  upk.sign = sign;

  if (exp <= IEEE754_EXP_MAX(ew) && exp > IEEE754_EXP_MIN) {
    if (man) {
      int32_t leadings = clz(man, IEEE754_RES_W(dw, ew));
      upk.exp = exp - leadings;
      upk.man = man << leadings;
    } else {
      upk.exp = IEEE754_EXP_MIN;
      upk.man = 0;
    }
  } else {
    upk.exp = exp;
    upk.man = man;
  }

  return ieee754_pack_(upk, dw, ew);
}

double ieee754todouble_(ieee754 input, int32_t dw, int32_t ew) {
  union {
    double  d;
    int64_t i;
  } conv;

  ieee754Unpacked upk = ieee754_unpack_(input, dw, ew);

  int64_t sign = upk.sign;
  int64_t exp  = upk.exp - IEEE754_BIAS(ew);
  int64_t man  = upk.man << (IEEE754_DP_MAN_W - IEEE754_MAN_W(dw, ew));

  exp += IEEE754_DP_BIAS;
  if (upk.exp == IEEE754_EXP_MIN && !man) { // Zero
    exp = 0;
  } else if (upk.exp == MASK(ew)) { // Infinity or NAN
    exp = MASK(IEEE754_DP_EXP_W);
  }

  if (exp > 0) {
    int32_t leadings = clz(man, IEEE754_DP_MAN_W);
    if ((exp - leadings) < 0) {
      leadings = exp;
    }
    exp -= leadings;
    man <<= leadings;
  } else {
    man <<= 3;

    int32_t shift = -exp + 1;
    int8_t sticky = (man & MASK(shift + 1))? 1 : 0;
    man = RSHIFT(man, shift) | sticky;
    exp = 0;

    uint8_t man_lsb    = (man & (1 << 3))? 1: 0;
    uint8_t guard_bit  = (man & (1 << 2))? 1: 0;
    uint8_t round_bit  = (man & (1 << 1))? 1: 0;
    uint8_t sticky_bit = (man & ((1 << 1) - 1))? 1: 0;
    man >>= 3;

    if (guard_bit & (man_lsb | round_bit | sticky_bit)) {
      man++;
    }
  }

  if (exp > MASK(IEEE754_DP_EXP_W)) { // Infinity
    exp = MASK(IEEE754_DP_EXP_W);
    man = 0;
  }

  man &= MASK(IEEE754_DP_F_W);

  conv.i = man;
  conv.i |= exp << IEEE754_DP_F_W;
  conv.i |= sign << (IEEE754_DP_DATA_W - 1);

  return conv.d;
}

int64_t ieee754toint_(ieee754 input, int32_t dw, int32_t ew) {
  int64_t ret;

  ieee754Unpacked upk = ieee754_unpack_(input, dw, ew);

  int32_t shift = IEEE754_F_W(dw, ew) - upk.exp;
  if (shift < 0) {
    ret = LSHIFT(upk.man, -shift);
    if (!ret && upk.man) {
      ret = ((uint64_t)1 << (64-1)) - 1;
    }
  } else {
    ret = RSHIFT(upk.man, shift);
  }

  if (upk.sign && ret) {
    ret = -ret;
  }

  return ret;
}

uint8_t double_is_sub(double val) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = val };
  int64_t man = conv.i & MASK(IEEE754_DP_F_W);
  int32_t exp = (conv.i >> IEEE754_DP_F_W) & MASK(IEEE754_DP_EXP_W);
  if (!exp && man) {
    return 1;
  } else {
    return 0;
  }
}

uint8_t double_is_nan(double val) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = val };
  int64_t man = conv.i & MASK(IEEE754_DP_F_W);
  int32_t exp = (conv.i >> IEEE754_DP_F_W) & MASK(IEEE754_DP_EXP_W);
  if (exp == MASK(IEEE754_DP_EXP_W) && man) {
    return 1;
  } else {
    return 0;
  }
}

uint8_t double_is_inf(double val) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = val };
  int64_t man = conv.i & MASK(IEEE754_DP_F_W);
  int32_t exp = (conv.i >> IEEE754_DP_F_W) & MASK(IEEE754_DP_EXP_W);
  if (exp == MASK(IEEE754_DP_EXP_W) && !man) {
    return 1;
  } else {
    return 0;
  }
}

int8_t double_get_sign(double val) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = val };
  int8_t sign = (conv.i >> (IEEE754_DP_DATA_W - 1)) & 1;
  return sign;
}

int32_t double_get_exp(double val) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = val };
  int32_t exp = (conv.i >> IEEE754_DP_F_W) & MASK(IEEE754_DP_EXP_W);
  if (!exp) exp++;
  exp -= IEEE754_DP_BIAS;
  return exp;
}

int64_t double_get_man(double val) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = val };
  int64_t man = conv.i & MASK(IEEE754_DP_F_W);
  int32_t exp = (conv.i >> IEEE754_DP_F_W) & MASK(IEEE754_DP_EXP_W);
  if (!double_is_sub(val) && !double_is_nan(val) && exp && exp != MASK(IEEE754_DP_EXP_W)) man |= MSB(IEEE754_DP_MAN_W);
  return man;
}

int fprintf_d(FILE *fp, const char *name, double val) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = val };
  int32_t exp = double_get_exp(val);
  int64_t man = double_get_man(val);
  int ret = fprintf(fp, "%s = %.3e (0x%016lx), man = 0x%014lx, exp = %d (0x%04hx), subnormal = %d, %s = %.16e\n", name, val, conv.i, man, exp, exp, double_is_sub(val), name, val);
  return ret;
}

char base2_str[29];
char zero_str[4] = "0.0";
char inf_str[4] = "Inf";
char nan_str[4] = "NaN";

char *base2(double num_d) {
  if (num_d == 0.0) return zero_str;
  if (double_is_inf(num_d)) return inf_str;
  if (double_is_nan(num_d)) return nan_str;
  int32_t exp = double_get_exp(num_d);
  int64_t man = double_get_man(num_d);
  double man_b10 = man * pow(2, -IEEE754_DP_F_W);
  if (double_get_sign(num_d)) man_b10 *= -1;
  sprintf(base2_str, "%.16f*2**%d", man_b10, exp);
  return base2_str;
}

uint8_t float_is_sub(float val) {
  union {
    float   f;
    int32_t i;
  } conv = { .f = val };
  int32_t man = conv.i & MASK(IEEE754_SP_F_W);
  int32_t exp = (conv.i >> IEEE754_SP_F_W) & MASK(IEEE754_SP_EXP_W);
  if (exp == 0 && man) {
    return 1;
  } else {
    return 0;
  }
}

uint8_t float_is_nan(float val) {
  union {
    float   f;
    int32_t i;
  } conv = { .f = val };
  int32_t man = conv.i & MASK(IEEE754_SP_F_W);
  int32_t exp = (conv.i >> IEEE754_SP_F_W) & MASK(IEEE754_SP_EXP_W);
  if (exp == MASK(IEEE754_SP_EXP_W) && man) {
    return 1;
  } else {
    return 0;
  }
}

uint8_t float_is_inf(float val) {
  union {
    float   f;
    int32_t i;
  } conv = { .f = val };
  int32_t man = conv.i & MASK(IEEE754_SP_F_W);
  int32_t exp = (conv.i >> IEEE754_SP_F_W) & MASK(IEEE754_SP_EXP_W);
  if (exp == MASK(IEEE754_SP_EXP_W) && !man) {
    return 1;
  } else {
    return 0;
  }
}

int8_t float_get_sign(float val) {
  union {
    float   f;
    int32_t i;
  } conv = { .f = val };
  int8_t sign = (conv.i >> (IEEE754_SP_DATA_W - 1)) & 1;
  return sign;
}

int32_t float_get_exp(float val) {
  union {
    float   f;
    int32_t i;
  } conv = { .f = val };
  int32_t exp = (conv.i >> IEEE754_SP_F_W) & MASK(IEEE754_SP_EXP_W);
  if (!exp) exp++;
  exp -= IEEE754_SP_BIAS;
  return exp;
}

int32_t float_get_man(float val) {
  union {
    float  f;
    int32_t i;
  } conv = { .f = val };
  int32_t man = conv.i & MASK(IEEE754_SP_F_W);
  int32_t exp = (conv.i >> IEEE754_SP_F_W) & MASK(IEEE754_SP_EXP_W);
  if (!float_is_sub(val) && !float_is_nan(val) && exp && exp != MASK(IEEE754_SP_EXP_W)) man |= MSB(IEEE754_SP_MAN_W);
  return man;
}

int fprintf_f(FILE *fp, const char *name, float val) {
  union {
    float   f;
    int32_t i;
  } conv = { .f = val };
  int32_t exp = float_get_exp(val);
  int32_t man = float_get_man(val);
  int ret = fprintf(fp, "%s = %.3e (0x%08x), man = 0x%06x, exp = %d (0x%04hx), subnormal = %d, %s = %.16e\n", name, val, conv.i, man, exp, exp, float_is_sub(val), name, val);
  return ret;
}
