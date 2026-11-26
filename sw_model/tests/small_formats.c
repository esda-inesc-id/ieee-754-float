// Exhaustive test of ffma (the two-product fmac stream a*b, c*1) in small formats: every
// a, b, c in every rounding mode against MPFR, correctly rounded with the format's
// subnormals and overflow. Formats too large to enumerate get random operands.
//
// usage: small_formats [data_w:exp_w[:kind[:random_cases]]] ... (kind 0 IEEE, 1 FN, 2
// FINITE; default: FP4 E2M1 and FP6 E3M2 IEEE and finite, FP8 E4M3 IEEE and FN, E5M2,
// all exhaustive, and bfloat16 random)

#include <math.h>
#include <mpfr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ieee754_model.h"

static int data_w, exp_w, prec, kind;
static double max_fin;  // the largest finite number
static mpfr_exp_t emin_fmt, emax_fmt;
static mpfr_t x, r, t;

// x rounded to the format in mode rnd (IEEE754_*), as a double
static double round_fmt(int mode) {
  static const mpfr_rnd_t m[] = {MPFR_RNDN, MPFR_RNDZ, MPFR_RNDD, MPFR_RNDU, MPFR_RNDN};
  mpfr_exp_t emin = mpfr_get_emin(), emax = mpfr_get_emax();
  mpfr_set_emin(emin_fmt);
  mpfr_set_emax(emax_fmt);
  double d;
  if (mode == IEEE754_RMM) {  // to nearest, ties away: the nearer of the two neighbours
    int inex = mpfr_set(r, x, MPFR_RNDZ);
    inex = mpfr_check_range(r, inex, MPFR_RNDZ);
    mpfr_subnormalize(r, inex, MPFR_RNDZ);
    double lo = mpfr_get_d(r, MPFR_RNDN);
    inex = mpfr_set(r, x, MPFR_RNDA);
    inex = mpfr_check_range(r, inex, MPFR_RNDA);
    mpfr_subnormalize(r, inex, MPFR_RNDA);
    double hi = mpfr_get_d(r, MPFR_RNDN);
    mpfr_set_emin(emin);
    mpfr_set_emax(emax);
    // the midpoint, exact in t; on overflow, half an ulp past the largest finite number
    double far = isinf(hi) ? lo + copysign(ldexp(1, (int)emax_fmt - prec), lo) : hi;
    mpfr_set_d(t, lo, MPFR_RNDN);
    mpfr_add_d(t, t, far, MPFR_RNDN);
    mpfr_div_2ui(t, t, 1, MPFR_RNDN);
    return mpfr_cmpabs(x, t) >= 0 ? hi : lo;
  }
  int inex = mpfr_set(r, x, m[mode]);
  inex = mpfr_check_range(r, inex, m[mode]);
  mpfr_subnormalize(r, inex, m[mode]);
  d = mpfr_get_d(r, MPFR_RNDN);
  mpfr_set_emin(emin);
  mpfr_set_emax(emax);
  return d;
}

static uint64_t rng = 0x9e3779b97f4a7c15ull;
static uint64_t rnd64(void) {
  rng ^= rng >> 12;
  rng ^= rng << 25;
  rng ^= rng >> 27;
  return rng * 0x2545f4914f6cdd1dull;
}

static long errors, cases;

static void check(uint64_t a, uint64_t b, uint64_t c, int mode) {
  double da = ieee754_to_double(a, data_w, exp_w), db = ieee754_to_double(b, data_w, exp_w),
         dc = ieee754_to_double(c, data_w, exp_w);
  double got = ieee754_to_double(ieee754_fma(a, b, c, data_w, exp_w), data_w, exp_w);
  double want;
  if (isnan(da) || isnan(db) || isnan(dc) || (isinf(da) && db == 0) || (da == 0 && isinf(db))) {
    want = NAN;
  } else if (isinf(da) || isinf(db) || isinf(dc)) {
    double p = isinf(da) || isinf(db) ? copysign(INFINITY, da) * copysign(1, db) : 0;
    want = isinf(p) && isinf(dc) && p != dc ? NAN : isinf(p) ? p : dc;
  } else {
    mpfr_set_d(x, da, MPFR_RNDN);
    mpfr_mul_d(x, x, db, MPFR_RNDN);  // exact: x has 600 bits
    mpfr_add_d(x, x, dc, MPFR_RNDN);
    if (mpfr_zero_p(x)) {
      // an exact zero: the sign of both terms if they agree, else +0 (-0 toward -inf)
      double p = da * db;
      int sp = signbit(p) != 0, sc = signbit(dc) != 0;
      want = sp == sc ? (sp ? -0.0 : 0.0) : (mode == IEEE754_RDN ? -0.0 : 0.0);
    } else {
      want = round_fmt(mode);
    }
  }
  if (kind != IEEE754_SPECIAL_IEEE && !isnan(want) && fabs(want) > max_fin) want = copysign(max_fin, want);
  cases++;
  int ok = isnan(want) ? isnan(got) : got == want && signbit(got) == signbit(want);
  if (!ok && errors++ < 10)
    printf("  mismatch e%dm%d mode %d: %a * %a + %a = %a, want %a\n", exp_w, prec - 1, mode, da, db, dc, got, want);
}

static const char *kname[] = {"", " fn", " finite"};

static void run(int dw, int ew, int k, long random_cases) {
  data_w = dw, exp_w = ew, prec = dw - ew, kind = k;
  ieee754_set_special(k);
  int bias = (1 << (ew - 1)) - 1;
  emin_fmt = 3 - bias - prec;
  // without infinities the largest exponent holds normal numbers; FN loses one value
  emax_fmt = k == IEEE754_SPECIAL_IEEE ? bias + 1 : bias + 2;
  max_fin = ldexp(2 - ldexp(1, 1 - prec) * (k == IEEE754_SPECIAL_FN ? 2 : 1), (int)emax_fmt - 1);
  mpfr_set_prec(r, prec);
  errors = cases = 0;
  uint64_t n = (uint64_t)1 << dw;
  for (int mode = 0; mode < 5; mode++) {
    ieee754_set_rounding(mode);
    if (!random_cases) {
      for (uint64_t a = 0; a < n; a++)
        for (uint64_t b = 0; b < n; b++)
          for (uint64_t c = 0; c < n; c++) check(a, b, c, mode);
    } else {
      for (long i = 0; i < random_cases; i++) check(rnd64() % n, rnd64() % n, rnd64() % n, mode);
    }
  }
  ieee754_set_rounding(IEEE754_RNE);
  ieee754_set_special(IEEE754_SPECIAL_IEEE);
  printf("ffma %d-bit e%dm%d%s %s: %ld cases, %ld mismatches\n", dw, ew, prec - 1, kname[k],
         random_cases ? "random" : "exhaustive", cases, errors);
}

int main(int argc, char **argv) {
  mpfr_init2(x, 600);
  mpfr_init2(r, 53);
  mpfr_init2(t, 600);
  long total = 0;
  if (argc > 1) {  // arguments: data_w:exp_w[:kind[:random_cases]], kind 0 IEEE, 1 FN, 2 FINITE
    for (int i = 1; i < argc; i++) {
      int dw = 0, ew = 0, k = 0;
      long rc = 0;
      sscanf(argv[i], "%d:%d:%d:%ld", &dw, &ew, &k, &rc);
      run(dw, ew, k, rc);
      total += errors;
    }
  } else {
    static const int fmts[][4] = {{4, 2, 0, 0}, {4, 2, 2, 0}, {6, 3, 0, 0}, {6, 3, 2, 0}, {8, 4, 0, 0},
                                  {8, 4, 1, 0}, {8, 5, 0, 0}, {16, 8, 0, 2000000}};
    for (unsigned i = 0; i < sizeof fmts / sizeof fmts[0]; i++) {
      run(fmts[i][0], fmts[i][1], fmts[i][2], fmts[i][3]);
      total += errors;
    }
  }
  return total != 0;
}
