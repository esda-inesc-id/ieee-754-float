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

// the format under study, and the fmac right guard
static int data_w, exp_w, prec, bias, rguard;
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
  long accs, lagged, lag_bits;  // fmac-1 normalization lag
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
  long accs0, lagged0, bits0, accs1, lagged1, bits1;
  ieee754_mac_stats(mac[0], &accs0, &lagged0, &bits0);
  for (int v = 0; v < 3; v++) {
    for (int i = 0; i < n; i++)
      ieee754_mac_push(mac[v], ieee754_from_double(a[i], data_w, exp_w), ieee754_from_double(b[i], data_w, exp_w));
    res[v] = ieee754_to_double(ieee754_mac_result(mac[v]), data_w, exp_w);
  }
  ieee754_mac_stats(mac[0], &accs1, &lagged1, &bits1);
  st[0].accs += accs1 - accs0;
  st[0].lagged += lagged1 - lagged0;
  st[0].lag_bits += bits1 - bits0;
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
  // fmac-1: % of products aligned with a lagging accumulator, mean missing bits then
  printf(" | lag %.2f%% %.1f\n", 100.0 * st[0].lagged / (st[0].accs ? st[0].accs : 1),
         st[0].lagged ? (double)st[0].lag_bits / st[0].lagged : 0.0);
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
    mac[v] = ieee754_mac_new(dw, ew, 0, rguard);
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

// Relative error against the condition number c = 2 sum|ab| / |s| of GenDot streams of
// length 100, binned by the decade of the measured c: the largest relative error of
// fmac-1, fmac-8, fma and mul+add, and the bound of Theorem 1 at the bin's upper edge.
static void sweep(int dw, int ew, int decades, int trials) {
  data_w = dw;
  exp_w = ew;
  prec = dw - ew;
  bias = (1 << (ew - 1)) - 1;
  emin_fmt = 3 - bias - prec;
  emax_fmt = bias + 1;
  mpfr_set_prec(fmt_tmp, prec);
  for (int v = 0; v < 3; v++) {
    mac[v] = ieee754_mac_new(dw, ew, 0, rguard);
    ieee754_mac_set_step(mac[v], vstep[v]);
  }
  enum { NB = 48 };
  int n = 100;
  double a[100], b[100], maxrel[NB][NV] = {{0}};
  long cnt[NB] = {0};
  for (int d = 1; d <= decades; d++) {
    for (int t = 0; t < trials; t++) {
      gendot(a, b, n, pow(10, d));
      exact_dot(a, b, n, exact_acc);
      double s = mpfr_get_d(exact_acc, MPFR_RNDN), sabs = 0;
      for (int i = 0; i < n; i++) sabs += fabs(a[i] * b[i]);
      if (s == 0) continue;
      int bin = (int)floor(log10(2 * sabs / fabs(s)));
      if (bin < 0) bin = 0;
      if (bin >= NB) continue;
      double res[NV];
      for (int v = 0; v < 3; v++) {
        for (int i = 0; i < n; i++)
          ieee754_mac_push(mac[v], ieee754_from_double(a[i], dw, ew), ieee754_from_double(b[i], dw, ew));
        res[v] = ieee754_to_double(ieee754_mac_result(mac[v]), dw, ew);
      }
      double acc = 0;
      for (int i = 0; i < n; i++) {
        mpfr_set_d(tmp, a[i], MPFR_RNDN);
        mpfr_mul_d(tmp, tmp, b[i], MPFR_RNDN);
        mpfr_add_d(tmp, tmp, acc, MPFR_RNDN);
        acc = round_fmt(tmp);
      }
      res[V_FMA] = acc;
      acc = 0;
      for (int i = 0; i < n; i++) {
        mpfr_set_d(tmp, a[i], MPFR_RNDN);
        mpfr_mul_d(tmp, tmp, b[i], MPFR_RNDN);
        double p = round_fmt(tmp);
        mpfr_set_d(tmp, acc, MPFR_RNDN);
        mpfr_add_d(tmp, tmp, p, MPFR_RNDN);
        acc = round_fmt(tmp);
      }
      res[V_MULADD] = acc;
      cnt[bin]++;
      for (int v = 0; v < NV - 1; v++) {
        if (v == V_FMACF) continue;
        mpfr_sub_d(tmp, exact_acc, res[v], MPFR_RNDN);
        double rel = fabs(mpfr_get_d(tmp, MPFR_RNDN)) / fabs(s);
        if (rel > maxrel[bin][v]) maxrel[bin][v] = rel;
      }
    }
  }
  for (int bin = 0; bin < NB; bin++) {
    if (!cnt[bin]) continue;
    // bound: u/2 + (n+1) 2^-(2p+g_R-3) S/|s|, with S/|s| = c/2 at the bin's upper edge
    double bound = ldexp(1, -prec) + (n + 1) * ldexp(1, -(2 * prec + rguard - 3)) * pow(10, bin + 1) / 2;
    printf("sweep f%d c=1e%d streams=%ld fmac1=%.3g fmac8=%.3g fma=%.3g muladd=%.3g bound=%.3g\n", dw, bin,
           cnt[bin], maxrel[bin][V_FMAC1], maxrel[bin][V_FMAC8], maxrel[bin][V_FMA], maxrel[bin][V_MULADD], bound);
  }
  for (int v = 0; v < 3; v++) ieee754_mac_free(mac[v]);
}

// One dot product of every variant: results in res[NV] (doubles in the format)
static void dot_all(const double *a, const double *b, int n, double *res) {
  for (int v = 0; v < 3; v++) {
    for (int i = 0; i < n; i++)
      ieee754_mac_push(mac[v], ieee754_from_double(a[i], data_w, exp_w), ieee754_from_double(b[i], data_w, exp_w));
    res[v] = ieee754_to_double(ieee754_mac_result(mac[v]), data_w, exp_w);
  }
  double acc = 0;
  for (int i = 0; i < n; i++) {
    mpfr_set_d(tmp, a[i], MPFR_RNDN);
    mpfr_mul_d(tmp, tmp, b[i], MPFR_RNDN);
    mpfr_add_d(tmp, tmp, acc, MPFR_RNDN);
    acc = round_fmt(tmp);
  }
  res[V_FMA] = acc;
  acc = 0;
  for (int i = 0; i < n; i++) {
    mpfr_set_d(tmp, a[i], MPFR_RNDN);
    mpfr_mul_d(tmp, tmp, b[i], MPFR_RNDN);
    double p = round_fmt(tmp);
    mpfr_set_d(tmp, acc, MPFR_RNDN);
    mpfr_add_d(tmp, tmp, p, MPFR_RNDN);
    acc = round_fmt(tmp);
  }
  res[V_MULADD] = acc;
  exact_dot(a, b, n, exact_acc);
  res[V_EXACT] = mpfr_get_d(exact_acc, MPFR_RNDN);  // exact (to binary64)
}

static void set_format(int dw, int ew) {
  data_w = dw;
  exp_w = ew;
  prec = dw - ew;
  bias = (1 << (ew - 1)) - 1;
  emin_fmt = 3 - bias - prec;
  emax_fmt = bias + 1;
  mpfr_set_prec(fmt_tmp, prec);
  for (int v = 0; v < 3; v++) {
    mac[v] = ieee754_mac_new(dw, ew, 0, rguard);
    ieee754_mac_set_step(mac[v], vstep[v]);
  }
}

// Applications: (1) a 63-tap windowed-sinc low-pass FIR filter on a signal of three
// tones plus noise: output SNR (dB) against the exact filter output; (2) k-means
// assignment: 2,000 points of dimension 128 to 16 centroids by squared distance,
// computed as the dot product of the differences with themselves: assignments that
// differ from the exact ones.
static void apps(int dw, int ew) {
  set_format(dw, ew);
  enum { TAPS = 63, LEN = 20000 };
  static double h[TAPS], x[LEN + TAPS], win[TAPS], res[NV];
  for (int k = 0; k < TAPS; k++) {
    double t = k - (TAPS - 1) / 2.0, fc = 0.1;
    double sinc = t == 0 ? 2 * fc : sin(2 * M_PI * fc * t) / (M_PI * t);
    h[k] = to_fmt(sinc * (0.54 - 0.46 * cos(2 * M_PI * k / (TAPS - 1))));
  }
  for (int i = 0; i < LEN + TAPS; i++)
    x[i] = to_fmt(0.5 * sin(0.05 * i) + 0.3 * sin(0.31 * i) + 0.1 * sin(1.7 * i) + 0.05 * nrand());
  double sig = 0, noise[NV] = {0};
  for (int i = 0; i < LEN; i++) {
    for (int k = 0; k < TAPS; k++) win[k] = x[i + k];
    dot_all(win, h, TAPS, res);
    sig += res[V_EXACT] * res[V_EXACT];
    for (int v = 0; v < NV - 1; v++) noise[v] += (res[v] - res[V_EXACT]) * (res[v] - res[V_EXACT]);
  }
  printf("app f%d fir snr_db", dw);
  for (int v = 0; v < NV - 1; v++) printf(" %s=%.1f", vname[v], noise[v] > 0 ? 10 * log10(sig / noise[v]) : INFINITY);
  // the reference: the exact output rounded once to the format
  double qn = 0;
  for (int i = 0; i < LEN; i++) {
    for (int k = 0; k < TAPS; k++) win[k] = x[i + k];
    exact_dot(win, h, TAPS, exact_acc);
    double e = mpfr_get_d(exact_acc, MPFR_RNDN), q = round_fmt(exact_acc);
    qn += (q - e) * (q - e);
  }
  printf(" rounded-exact=%.1f\n", 10 * log10(sig / qn));

  enum { PTS = 2000, DIM = 128, K = 16 };
  static double cent[K][DIM], pt[DIM], d[DIM];
  for (int c = 0; c < K; c++)
    for (int j = 0; j < DIM; j++) cent[c][j] = to_fmt(nrand());
  long wrong[NV] = {0};
  for (int p = 0; p < PTS; p++) {
    int c0 = (int)(urand() * K);
    for (int j = 0; j < DIM; j++) pt[j] = to_fmt(cent[c0][j] + 4 * nrand());
    double best[NV];
    int arg[NV];
    for (int v = 0; v < NV; v++) best[v] = INFINITY, arg[v] = -1;
    for (int c = 0; c < K; c++) {
      for (int j = 0; j < DIM; j++) d[j] = to_fmt(pt[j] - cent[c][j]);
      dot_all(d, d, DIM, res);
      for (int v = 0; v < NV; v++)
        if (res[v] < best[v]) best[v] = res[v], arg[v] = c;
    }
    for (int v = 0; v < NV - 1; v++) wrong[v] += arg[v] != arg[V_EXACT];
  }
  printf("app f%d kmeans wrong_assignments_of_%d", dw, PTS);
  for (int v = 0; v < NV - 1; v++) printf(" %s=%ld", vname[v], wrong[v]);
  printf("\n");
  for (int v = 0; v < 3; v++) ieee754_mac_free(mac[v]);
}

int main(int argc, char **argv) {
  // arguments: the formats to run, e.g. "16 32 64" (default all); "-g N" sets the fmac
  // right guard; "-s" runs the condition sweep instead of the study
  int run16 = 0, run32 = 0, run64 = 0, nfmt = 0, do_sweep = 0, do_apps = 0;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "-g") && i + 1 < argc) {
      rguard = atoi(argv[++i]);
    } else if (!strcmp(argv[i], "-s")) {
      do_sweep = 1;
    } else if (!strcmp(argv[i], "-a")) {
      do_apps = 1;
    } else {
      nfmt++;
      run16 |= atoi(argv[i]) == 16;
      run32 |= atoi(argv[i]) == 32;
      run64 |= atoi(argv[i]) == 64;
    }
  }
  if (!nfmt) run16 = run32 = run64 = 1;
  mpfr_init2(exact_acc, 4500);
  mpfr_init2(tmp, 4500);
  mpfr_init2(prod, 128);
  mpfr_init2(fmt_tmp, 53);

  if (do_apps) {
    if (run16) apps(16, 5);
    if (run32) apps(32, 8);
    return 0;
  }
  if (do_sweep) {
    if (run16) sweep(16, 5, 5, 300);
    if (run32) sweep(32, 8, 16, 300);
    if (run64) sweep(64, 11, 32, 100);
    return 0;
  }
  printf("round to nearest even, fmac right guard %d; per variant: max ulp, mean ulp, %% correctly rounded\n",
         rguard);
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
