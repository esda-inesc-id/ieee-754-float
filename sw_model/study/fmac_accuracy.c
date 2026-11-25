// fmac accuracy study: dot products and sums in binary16, binary32 and binary64 on the
// bit-accurate fmac model, against the exact result and the usual alternatives.
//
// Variants:
//   fmac-1     the RTL: accumulator normalized by at most 1 bit per accumulation
//   fmac-8     at most 8 bits per accumulation
//   fmac-full  fully normalized every accumulation
//   fma        chain of fused multiply-adds, rounded to the format each step
//   mul+add    separate multiply and add, each rounded to the format
//   exact      exact sum rounded once (a Kulisch accumulator)
//
// Streams:
//   normal     a, b ~ N(0,1)
//   relu       a = max(0, N(0,1)), b ~ N(0, 0.05): an ML layer
//   sum        a ~ U(0,1), b = 1: a long sum
//   gendot     ill-conditioned dot products (Ogita, Rump and Oishi, GenDot)
//   cancel     near-cancelling large products followed by small ones
//
// All roundings to the format (fma, mul+add, exact) use MPFR, to nearest even.
// Errors are |result - exact| in ulps of the exact result rounded to the format.
// "bound" is the largest (|err| - ulp/2) / ((n+1) sum|ab|) of fmac-1, as a power of 2,
// against the proven 2^-(2p-3) (Section "Error Bound" of the paper).

#include <math.h>
#include <mpfr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ieee754_model.h"

enum { V_FMAC1, V_FMAC8, V_FMACF, V_FMA, V_MULADD, V_EXACT, NV };
static const char *vname[NV] = {"fmac-1", "fmac-8", "fmac-full", "fma", "mul+add", "exact"};
static const int vstep[3] = {1, 8, 128};

// the format under study
static int data_w, exp_w, prec, bias;
static mpfr_exp_t emin_fmt, emax_fmt;

// Deterministic random numbers (xorshift64*)
static uint64_t rng_state = 0x9e3779b97f4a7c15ull;
static double urand(void) {
  rng_state ^= rng_state >> 12;
  rng_state ^= rng_state << 25;
  rng_state ^= rng_state >> 27;
  return (double)((rng_state * 0x2545f4914f6cdd1dull) >> 11) * 0x1p-53;
}
static double nrand(void) {
  double u = urand(), v = urand();
  return sqrt(-2.0 * log(u + 0x1p-60)) * cos(6.283185307179586 * v);
}

// x rounded to the format (to nearest even), as a double
static double to_fmt(double x) { return ieee754_to_double(ieee754_from_double(x, data_w, exp_w), data_w, exp_w); }

// y = x rounded to the format, with its subnormals and overflow
static mpfr_t fmt_tmp;
static double round_fmt(mpfr_t x) {
  mpfr_exp_t emin = mpfr_get_emin(), emax = mpfr_get_emax();
  mpfr_set_emin(emin_fmt);
  mpfr_set_emax(emax_fmt);
  int inex = mpfr_set(fmt_tmp, x, MPFR_RNDN);
  inex = mpfr_check_range(fmt_tmp, inex, MPFR_RNDN);
  mpfr_subnormalize(fmt_tmp, inex, MPFR_RNDN);
  mpfr_set_emin(emin);
  mpfr_set_emax(emax);
  return mpfr_get_d(fmt_tmp, MPFR_RNDN);
}

static mpfr_t exact_acc, tmp, prod;
static void exact_dot(const double *a, const double *b, int n, mpfr_t out) {
  mpfr_set_zero(out, 1);
  for (int i = 0; i < n; i++) {
    mpfr_set_d(prod, a[i], MPFR_RNDN);
    mpfr_mul_d(prod, prod, b[i], MPFR_RNDN);
    mpfr_add(out, out, prod, MPFR_RNDN);
  }
}

typedef struct {
  double max_ulp, sum_ulp, bound;
  long count, correct;
} stat;

static ieee754_mac *mac[3];

// Runs every variant on one stream and adds its errors to st[NV].
static void run(const double *a, const double *b, int n, stat *st) {
  exact_dot(a, b, n, exact_acc);
  double ref = round_fmt(exact_acc);
  int e;
  frexp(ref, &e);
  int ulp_e = e - prec, ulp_min = 3 - bias - prec - 1;
  double ulp = ldexp(1.0, ref == 0.0 || ulp_e < ulp_min ? ulp_min : ulp_e);
  double sabs = 0;
  for (int i = 0; i < n; i++) sabs += fabs(a[i] * b[i]);

  double res[NV];
  for (int v = 0; v < 3; v++) {
    for (int i = 0; i < n; i++)
      ieee754_mac_push(mac[v], ieee754_from_double(a[i], data_w, exp_w), ieee754_from_double(b[i], data_w, exp_w));
    res[v] = ieee754_to_double(ieee754_mac_result(mac[v]), data_w, exp_w);
  }
  double acc = 0;
  for (int i = 0; i < n; i++) {  // fma: acc = round(a*b + acc)
    mpfr_set_d(tmp, a[i], MPFR_RNDN);
    mpfr_mul_d(tmp, tmp, b[i], MPFR_RNDN);
    mpfr_add_d(tmp, tmp, acc, MPFR_RNDN);
    acc = round_fmt(tmp);
  }
  res[V_FMA] = acc;
  acc = 0;
  for (int i = 0; i < n; i++) {  // mul+add: acc = round(acc + round(a*b))
    mpfr_set_d(tmp, a[i], MPFR_RNDN);
    mpfr_mul_d(tmp, tmp, b[i], MPFR_RNDN);
    double p = round_fmt(tmp);
    mpfr_set_d(tmp, acc, MPFR_RNDN);
    mpfr_add_d(tmp, tmp, p, MPFR_RNDN);
    acc = round_fmt(tmp);
  }
  res[V_MULADD] = acc;
  res[V_EXACT] = ref;

  for (int v = 0; v < NV; v++) {
    mpfr_sub_d(tmp, exact_acc, res[v], MPFR_RNDN);
    double err_abs = fabs(mpfr_get_d(tmp, MPFR_RNDN));
    double err = err_abs / ulp;
    stat *s = &st[v];
    if (err > s->max_ulp) s->max_ulp = err;
    s->sum_ulp += err;
    s->count++;
    s->correct += res[v] == ref;
    if (v == V_FMAC1 && sabs > 0) {
      double r = (err_abs - 0.5 * ulp) / ((n + 1) * sabs);
      if (r > s->bound) s->bound = r;
    }
  }
}

static void report(const char *stream, const char *param, stat *st) {
  printf("f%-2d %-7s %-11s", data_w, stream, param);
  for (int v = 0; v < NV; v++) printf(" | %9.3g %9.3g %5.1f%%", st[v].max_ulp, st[v].sum_ulp / st[v].count,
                                      100.0 * st[v].correct / st[v].count);
  if (st[V_FMAC1].bound > 0)
    printf(" | 2^%.1f", log2(st[V_FMAC1].bound));
  else
    printf(" | -");
  printf("\n");
}

// Ogita, Rump and Oishi, "Accurate sum and dot product", Algorithm 6.1 (GenDot), in the
// format, with the exact dot product of the generated terms.
static void gendot(double *x, double *y, int n, double cond) {
  double fmax = ieee754_to_double(((uint64_t)1 << (data_w - 1)) - ((uint64_t)1 << (data_w - exp_w - 1)) - 1,
                                  data_w, exp_w);
retry:;
  int n2 = n / 2;
  double b = log2(cond);
  for (int i = 0; i < n2; i++) {
    int e = (int)lround(urand() * b / 2);
    if (i == 0) e = (int)lround(b / 2) + 1;
    if (i == n2 - 1) e = 0;
    x[i] = to_fmt(ldexp(2 * urand() - 1, e));
    y[i] = to_fmt(ldexp(2 * urand() - 1, e));
  }
  for (int i = n2; i < n; i++) {
    int e = (int)lround(b / 2 * (1.0 - (double)(i - n2) / (n - n2 - 1)));
    x[i] = to_fmt(ldexp(2 * urand() - 1, e));
    exact_dot(x, y, i, tmp);
    y[i] = to_fmt((ldexp(2 * urand() - 1, e) - mpfr_get_d(tmp, MPFR_RNDN)) / x[i]);
    // in a narrow format a small x[i] can overflow y[i] or a product: draw again
    if (!(fabs(y[i]) <= fmax) || !(fabs(x[i] * y[i]) <= fmax)) goto retry;
  }
  for (int i = n - 1; i > 0; i--) {  // random order
    int j = (int)(urand() * (i + 1));
    double t = x[i];
    x[i] = x[j];
    x[j] = t;
    t = y[i];
    y[i] = y[j];
    y[j] = t;
  }
}

// Blocks of 16: two large products (2^(p-4)) cancelled two products later (same
// accumulator) down to a few ulps, then small products (2^-(p/2-2)).
static void cancel(double *a, double *b, int n) {
  for (int i = 0; i < n; i += 16) {
    for (int k = 0; k < 2 && i + k + 2 < n; k++) {
      double big = to_fmt(ldexp(1 + urand(), prec - 4));
      a[i + k] = big;
      b[i + k] = 1;
      a[i + k + 2] = -to_fmt(big - ldexp(1 + (int)(urand() * 8), -3));
      b[i + k + 2] = 1;
    }
    for (int k = 4; k < 16 && i + k < n; k++) {
      a[i + k] = to_fmt(nrand() * ldexp(1, -(prec / 2 - 2)));
      b[i + k] = to_fmt(1 + urand());
    }
  }
}

static void study(int dw, int ew, double scale, const double *conds, int nconds) {
  data_w = dw;
  exp_w = ew;
  prec = dw - ew;
  bias = (1 << (ew - 1)) - 1;
  emin_fmt = 3 - bias - prec;
  emax_fmt = bias + 1;
  mpfr_set_prec(fmt_tmp, prec);
  for (int v = 0; v < 3; v++) {
    mac[v] = ieee754_mac_new(dw, ew, 0, 0);
    ieee754_mac_set_step(mac[v], vstep[v]);
  }
  int nmax = 100000;
  double *a = malloc(nmax * sizeof *a), *b = malloc(nmax * sizeof *b);
  char p[32];

  static const int dot_n[] = {16, 64, 256, 1024, 4096};
  for (int s = 0; s < 2; s++) {
    for (int k = 0; k < 5; k++) {
      int n = dot_n[k], trials = (int)(scale * 200000 / n);
      if (trials < 50) trials = 50;
      stat st[NV] = {0};
      for (int t = 0; t < trials; t++) {
        for (int i = 0; i < n; i++) {
          if (s == 0) {
            a[i] = to_fmt(nrand());
            b[i] = to_fmt(nrand());
          } else {
            double x = nrand();
            a[i] = to_fmt(x > 0 ? x : 0);
            b[i] = to_fmt(0.05 * nrand());
          }
        }
        run(a, b, n, st);
      }
      snprintf(p, sizeof p, "n=%d", n);
      report(s == 0 ? "normal" : "relu", p, st);
    }
  }

  static const int sum_n[] = {1000, 10000, 100000};
  for (int k = 0; k < 3; k++) {
    int n = sum_n[k], trials = (int)(scale * 2000000 / n);
    if (trials < 5) trials = 5;
    stat st[NV] = {0};
    for (int t = 0; t < trials; t++) {
      for (int i = 0; i < n; i++) {
        a[i] = to_fmt(urand());
        b[i] = 1;
      }
      run(a, b, n, st);
    }
    snprintf(p, sizeof p, "n=%d", n);
    report("sum", p, st);
  }

  for (int k = 0; k < nconds; k++) {
    int n = 100, trials = (int)(scale * 2000);
    stat st[NV] = {0};
    for (int t = 0; t < trials; t++) {
      gendot(a, b, n, conds[k]);
      run(a, b, n, st);
    }
    snprintf(p, sizeof p, "c=%.0e", conds[k]);
    report("gendot", p, st);
  }

  static const int cancel_n[] = {16, 256, 4096};
  for (int k = 0; k < 3; k++) {
    int n = cancel_n[k], trials = (int)(scale * 2000000 / n);
    stat st[NV] = {0};
    for (int t = 0; t < trials; t++) {
      cancel(a, b, n);
      run(a, b, n, st);
    }
    snprintf(p, sizeof p, "n=%d", n);
    report("cancel", p, st);
  }

  for (int v = 0; v < 3; v++) ieee754_mac_free(mac[v]);
  free(a);
  free(b);
}

int main(int argc, char **argv) {
  // optional argument: the formats to run, e.g. "16 32 64" (default all)
  int run16 = argc < 2, run32 = argc < 2, run64 = argc < 2;
  for (int i = 1; i < argc; i++) {
    run16 |= atoi(argv[i]) == 16;
    run32 |= atoi(argv[i]) == 32;
    run64 |= atoi(argv[i]) == 64;
  }
  mpfr_init2(exact_acc, 4500);
  mpfr_init2(tmp, 4500);
  mpfr_init2(prod, 128);
  mpfr_init2(fmt_tmp, 53);

  printf("round to nearest even; per variant: max ulp, mean ulp, %% correctly rounded\n");
  printf("%-3s %-7s %-11s", "fmt", "stream", "param");
  for (int v = 0; v < NV; v++) printf(" | %-27s", vname[v]);
  printf(" | fmac-1 bound\n");

  static const double c16[] = {1e2, 1e3, 1e4};
  static const double c32[] = {1e3, 1e6, 1e9, 1e12};
  static const double c64[] = {1e6, 1e12, 1e18, 1e24, 1e30};
  if (run16) study(16, 5, 1.0, c16, 3);
  if (run32) study(32, 8, 1.0, c32, 4);
  if (run64) study(64, 11, 0.25, c64, 5);

  mpfr_clear(exact_acc);
  mpfr_clear(tmp);
  mpfr_clear(prod);
  mpfr_clear(fmt_tmp);
  return 0;
}
