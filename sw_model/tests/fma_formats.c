// Test of ffma (the two-product fmac stream a*b, c*1) in any format from FP4 to binary128,
// against MPFR: every a, b, c in every rounding mode for formats of up to 8 bits, random
// operands for wider formats. Encodings are decoded exactly into MPFR, so no format
// goes through a double.
//
// usage: fma_formats [data_w:exp_w[:kind[:random_cases]]] ... (kind 0 IEEE, 1 FN, 2
// FINITE; default: FP4 E2M1 and FP6 E3M2 IEEE and finite, FP8 E4M3 IEEE and FN, E5M2,
// all exhaustive; bfloat16, binary32, binary64 and binary128 random)

#include <math.h>
#include <mpfr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ieee754_model.h"

typedef ieee754_u128 u128;

static int data_w, exp_w, prec, kind, bias;
static mpfr_exp_t emin_fmt, emax_fmt;
static mpfr_t va, vb, vc, want, got, prod, mid, sum, maxfin;

enum { V_NUM, V_NAN, V_INF };

// Decodes an encoding into v; returns V_NUM, V_NAN or V_INF (v then holds the sign)
static int decode(u128 bits, mpfr_t v) {
  int sign = (int)(bits >> (data_w - 1)) & 1;
  int fw = prec - 1;
  u128 frac = bits & (((u128)1 << fw) - 1);
  int e = (int)(bits >> fw) & ((1 << exp_w) - 1);
  int ones = e == (1 << exp_w) - 1;
  int is_nan = kind == IEEE754_SPECIAL_IEEE ? ones && frac : kind == IEEE754_SPECIAL_FN && ones && frac == (((u128)1 << fw) - 1);
  if (is_nan) return V_NAN;
  if (kind == IEEE754_SPECIAL_IEEE && ones) {
    mpfr_set_si(v, sign ? -1 : 1, MPFR_RNDN);
    return V_INF;
  }
  u128 man = frac | (e ? (u128)1 << fw : 0);
  mpfr_set_ui(v, (unsigned long)(uint64_t)(man >> 64), MPFR_RNDN);
  mpfr_mul_2ui(v, v, 64, MPFR_RNDN);
  mpfr_add_ui(v, v, (unsigned long)(uint64_t)man, MPFR_RNDN);  // exact: v has 300 bits
  mpfr_mul_2si(v, v, (e ? e : 1) - bias - fw, MPFR_RNDN);
  if (sign) mpfr_neg(v, v, MPFR_RNDN);
  if (mpfr_zero_p(v) && sign) mpfr_set_zero(v, -1);
  return V_NUM;
}

// want = a*b + c rounded to the format in mode (IEEE754_*), with subnormals and overflow
static void round_fma(int mode) {
  static const mpfr_rnd_t m[] = {MPFR_RNDN, MPFR_RNDZ, MPFR_RNDD, MPFR_RNDU, MPFR_RNDZ};
  mpfr_exp_t emin = mpfr_get_emin(), emax = mpfr_get_emax();
  mpfr_set_emin(emin_fmt);
  mpfr_set_emax(emax_fmt);
  int inex = mpfr_fma(want, va, vb, vc, m[mode]);
  inex = mpfr_check_range(want, inex, m[mode]);
  inex = mpfr_subnormalize(want, inex, m[mode]);
  mpfr_set_emin(emin);
  mpfr_set_emax(emax);
  if (mode != IEEE754_RMM || inex == 0) return;
  // ties away: want is the truncation; take the next value away from zero if the exact
  // result is at or past the midpoint (on overflow, half an ulp past the largest number)
  mpfr_set(mid, want, MPFR_RNDN);
  mpfr_set_emin(emin_fmt);
  mpfr_set_emax(emax_fmt);
  mpfr_t away;
  mpfr_init2(away, prec);
  int ia = mpfr_fma(away, va, vb, vc, MPFR_RNDA);
  ia = mpfr_check_range(away, ia, MPFR_RNDA);
  mpfr_subnormalize(away, ia, MPFR_RNDA);
  mpfr_set_emin(emin);
  mpfr_set_emax(emax);
  mpfr_ptr two[2] = {prod, vc};
  mpfr_sum(sum, two, 2, MPFR_RNDN);  // the sign of the exact result
  int sgn = mpfr_sgn(sum);
  if (mpfr_inf_p(away)) {
    mpfr_set_si_2exp(mid, sgn, emax_fmt - prec, MPFR_RNDN);
    mpfr_div_2ui(mid, mid, 1, MPFR_RNDN);
    mpfr_add(mid, mid, want, MPFR_RNDN);
  } else {
    mpfr_add(mid, want, away, MPFR_RNDN);
    mpfr_div_2ui(mid, mid, 1, MPFR_RNDN);
  }
  // sign of a*b + c - mid, exact: prod is exact and mpfr_sum is correctly rounded
  mpfr_neg(mid, mid, MPFR_RNDN);
  mpfr_ptr terms[3] = {prod, vc, mid};
  mpfr_sum(sum, terms, 3, MPFR_RNDN);
  if (mpfr_sgn(sum) * sgn >= 0) mpfr_set(want, away, MPFR_RNDN);
  mpfr_clear(away);
}

static uint64_t rng = 0x9e3779b97f4a7c15ull;
static uint64_t rnd64(void) {
  rng ^= rng >> 12;
  rng ^= rng << 25;
  rng ^= rng >> 27;
  return rng * 0x2545f4914f6cdd1dull;
}

static long errors, cases;

static void print_hex(const char *name, u128 x) {
  printf(" %s=%016llx%016llx", name, (unsigned long long)(uint64_t)(x >> 64), (unsigned long long)(uint64_t)x);
}

static void check(u128 a, u128 b, u128 c, int mode) {
  int ka = decode(a, va), kb = decode(b, vb), kc = decode(c, vc);
  u128 res = ieee754_fma_w(a, b, c, data_w, exp_w);
  int kr = decode(res, got);
  int want_kind = V_NUM, want_sign = 0;
  int a0 = ka == V_NUM && mpfr_zero_p(va), b0 = kb == V_NUM && mpfr_zero_p(vb);
  if (ka == V_NAN || kb == V_NAN || kc == V_NAN || (ka == V_INF && b0) || (a0 && kb == V_INF)) {
    want_kind = V_NAN;
  } else if (ka == V_INF || kb == V_INF || kc == V_INF) {
    int pinf = ka == V_INF || kb == V_INF;
    int psign = (mpfr_signbit(va) != 0) ^ (mpfr_signbit(vb) != 0);
    int csign = mpfr_signbit(vc) != 0;
    if (pinf && kc == V_INF && psign != csign)
      want_kind = V_NAN;
    else
      want_kind = V_INF, want_sign = pinf ? psign : csign;
  } else {
    mpfr_mul(prod, va, vb, MPFR_RNDN);  // exact: prod has 2 * 113 bits
    round_fma(mode);
    if (mpfr_zero_p(want)) {
      int inexact = !(mpfr_zero_p(prod) && mpfr_zero_p(vc)) && !(mpfr_cmpabs(prod, vc) == 0 && mpfr_sgn(prod) != mpfr_sgn(vc));
      if (!inexact) {  // an exact zero: the sign of both terms if they agree, else by the mode
        int sp = mpfr_signbit(prod) != 0, sc = mpfr_signbit(vc) != 0;
        mpfr_set_zero(want, sp == sc ? (sp ? -1 : 1) : (mode == IEEE754_RDN ? -1 : 1));
      }
    }
    if (mpfr_inf_p(want)) {
      want_kind = V_INF, want_sign = mpfr_signbit(want) != 0;
    }
    if (kind != IEEE754_SPECIAL_IEEE && (want_kind == V_INF || (want_kind == V_NUM && mpfr_cmpabs(want, maxfin) > 0))) {
      int s = want_kind == V_INF ? want_sign : mpfr_signbit(want) != 0;
      mpfr_set(want, maxfin, MPFR_RNDN);
      if (s) mpfr_neg(want, want, MPFR_RNDN);
      want_kind = V_NUM;
    }
  }
  cases++;
  int ok;
  if (want_kind == V_NAN)
    ok = kr == V_NAN;
  else if (want_kind == V_INF)
    ok = kr == V_INF && (mpfr_signbit(got) != 0) == want_sign;
  else
    ok = kr == V_NUM && mpfr_equal_p(got, want) && (mpfr_signbit(got) != 0) == (mpfr_signbit(want) != 0);
  if (!ok && errors++ < 10) {
    printf("  mismatch %d-bit e%d mode %d:", data_w, exp_w, mode);
    print_hex("a", a);
    print_hex("b", b);
    print_hex("c", c);
    print_hex("got", res);
    mpfr_printf(" want %s%.40Rg\n", want_kind == V_NAN ? "NaN " : want_kind == V_INF ? "inf " : "", want);
  }
}

static const char *kname[] = {"", " fn", " finite"};

static void run(int dw, int ew, int k, long random_cases) {
  data_w = dw, exp_w = ew, prec = dw - ew, kind = k;
  ieee754_set_special(k);
  bias = (1 << (ew - 1)) - 1;
  emin_fmt = 3 - bias - prec;
  // without infinities the largest exponent holds normal numbers; FN loses one value
  emax_fmt = k == IEEE754_SPECIAL_IEEE ? bias + 1 : bias + 2;
  mpfr_set_prec(want, prec);
  mpfr_set_prec(maxfin, prec);
  // the largest finite number: 2^emax - ulp, or 2^emax - 2 ulp in FN (its all-ones code is NaN)
  mpfr_set_ui_2exp(mid, 1, emax_fmt, MPFR_RNDN);
  mpfr_set_ui_2exp(sum, k == IEEE754_SPECIAL_FN ? 2 : 1, emax_fmt - prec, MPFR_RNDN);
  mpfr_sub(maxfin, mid, sum, MPFR_RNDN);
  errors = cases = 0;
  for (int mode = 0; mode < 5; mode++) {
    ieee754_set_rounding(mode);
    if (!random_cases) {
      u128 n = (u128)1 << dw;
      for (u128 a = 0; a < n; a++)
        for (u128 b = 0; b < n; b++)
          for (u128 c = 0; c < n; c++) check(a, b, c, mode);
    } else {
      u128 msk = dw == 128 ? ~(u128)0 : ((u128)1 << dw) - 1;
      for (long i = 0; i < random_cases; i++) {
        u128 op[3];
        for (int j = 0; j < 3; j++) {
          op[j] = (((u128)rnd64() << 64) | rnd64()) & msk;
          // half the time, an exponent near the others' sum so that the terms interact
          if (j == 2 && (rnd64() & 1)) {
            int ea = (int)(op[0] >> (prec - 1)) & ((1 << ew) - 1), eb = (int)(op[1] >> (prec - 1)) & ((1 << ew) - 1);
            int e = ea + eb - bias + (int)(rnd64() % 9) - 4;
            if (e > 0 && e < (1 << ew) - 1)
              op[2] = (op[2] & ~((((u128)1 << ew) - 1) << (prec - 1))) | ((u128)e << (prec - 1));
          }
        }
        check(op[0], op[1], op[2], mode);
      }
    }
  }
  ieee754_set_rounding(IEEE754_RNE);
  ieee754_set_special(IEEE754_SPECIAL_IEEE);
  printf("ffma %d-bit e%dm%d%s %s: %ld cases, %ld mismatches\n", dw, ew, prec - 1, kname[k],
         random_cases ? "random" : "exhaustive", cases, errors);
  fflush(stdout);
}

int main(int argc, char **argv) {
  mpfr_set_default_prec(300);
  mpfr_inits2(300, va, vb, vc, got, prod, mid, (mpfr_ptr)0);
  mpfr_init2(sum, 64);
  mpfr_init2(want, 113);
  mpfr_init2(maxfin, 113);
  long total = 0;
  if (argc > 1) {
    for (int i = 1; i < argc; i++) {
      int dw = 0, ew = 0, k = 0;
      long rc = 0;
      sscanf(argv[i], "%d:%d:%d:%ld", &dw, &ew, &k, &rc);
      run(dw, ew, k, rc);
      total += errors;
    }
  } else {
    static const int fmts[][4] = {{4, 2, 0, 0},       {4, 2, 2, 0},       {6, 3, 0, 0},      {6, 3, 2, 0},
                                  {8, 4, 0, 0},       {8, 4, 1, 0},       {8, 5, 0, 0},      {16, 8, 0, 1000000},
                                  {32, 8, 0, 1000000}, {64, 11, 0, 1000000}, {128, 15, 0, 1000000}};
    for (unsigned i = 0; i < sizeof fmts / sizeof fmts[0]; i++) {
      run(fmts[i][0], fmts[i][1], fmts[i][2], fmts[i][3]);
      total += errors;
    }
  }
  return total != 0;
}
