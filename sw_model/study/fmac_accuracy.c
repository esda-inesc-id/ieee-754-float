// fmac accuracy study: binary32 dot products and sums on the bit-accurate fmac model,
// against the exact result (MPFR) and the usual alternatives.
//
// Variants:
//   fmac-1     the RTL: accumulator normalized by at most 1 bit per accumulation
//   fmac-8     at most 8 bits per accumulation
//   fmac-full  fully normalized every accumulation
//   fma        chain of fused multiply-adds, rounded to binary32 each step
//   mul+add    separate multiply and add, each rounded to binary32
//   exact      exact sum rounded once (a Kulisch accumulator)
//
// Streams:
//   normal     a, b ~ N(0,1)
//   relu       a = max(0, N(0,1)), b ~ N(0, 0.05): an ML layer
//   sum        a ~ U(0,1), b = 1: a long sum
//   gendot     ill-conditioned dot products (Ogita, Rump and Oishi, GenDot)
//   cancel     near-cancelling large products followed by small ones
//
// Errors are |result - exact| in ulps of the exact result rounded to binary32.
// For fmac-1, "bound" is the largest (|err| - ulp/2) / ((n+2) sum|ab|), as a power of 2.

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

static uint64_t fbits(float x) {
  uint32_t u;
  memcpy(&u, &x, 4);
  return u;
}
static float bitsf(uint64_t b) {
  uint32_t u = (uint32_t)b;
  float x;
  memcpy(&x, &u, 4);
  return x;
}

// Exact dot product of the first n terms; wide enough for any binary32 dot product.
static mpfr_t exact_acc, tmp;
static void exact_dot(const float *a, const float *b, int n, mpfr_t out) {
  mpfr_set_zero(out, 1);
  for (int i = 0; i < n; i++) mpfr_add_d(out, out, (double)a[i] * (double)b[i], MPFR_RNDN);
}

typedef struct {
  double max_ulp, sum_ulp, bound;
  long count, correct;
} stat;

static ieee754_mac *mac[3];

// Runs every variant on one stream and adds its errors to st[NV].
static void run(const float *a, const float *b, int n, stat *st) {
  exact_dot(a, b, n, exact_acc);
  float ref = mpfr_get_flt(exact_acc, MPFR_RNDN);
  int e;
  frexpf(ref, &e);
  double ulp = ref == 0.0f ? 0x1p-149 : ldexp(1.0, (e - 24 < -149 ? -149 : e - 24));
  double sabs = 0;
  for (int i = 0; i < n; i++) sabs += fabs((double)a[i] * (double)b[i]);

  float res[NV];
  for (int v = 0; v < 3; v++) {
    for (int i = 0; i < n; i++) ieee754_mac_push(mac[v], fbits(a[i]), fbits(b[i]));
    res[v] = bitsf(ieee754_mac_result(mac[v]));
  }
  float acc = 0;
  for (int i = 0; i < n; i++) acc = fmaf(a[i], b[i], acc);
  res[V_FMA] = acc;
  acc = 0;
  for (int i = 0; i < n; i++) {
    float p = a[i] * b[i];
    acc = acc + p;
  }
  res[V_MULADD] = acc;
  res[V_EXACT] = ref;

  for (int v = 0; v < NV; v++) {
    mpfr_sub_d(tmp, exact_acc, (double)res[v], MPFR_RNDN);
    double err = fabs(mpfr_get_d(tmp, MPFR_RNDN)) / ulp;
    stat *s = &st[v];
    if (err > s->max_ulp) s->max_ulp = err;
    s->sum_ulp += err;
    s->count++;
    s->correct += res[v] == ref;
    if (v == V_FMAC1 && sabs > 0) {
      double r = (err - 0.5) * ulp / ((n + 2) * sabs);
      if (r > s->bound) s->bound = r;
    }
  }
}

static void report(const char *stream, const char *param, stat *st) {
  printf("%-7s %-11s", stream, param);
  for (int v = 0; v < NV; v++) printf(" | %9.3g %9.3g %5.1f%%", st[v].max_ulp, st[v].sum_ulp / st[v].count,
                                      100.0 * st[v].correct / st[v].count);
  if (st[V_FMAC1].bound > 0)
    printf(" | 2^%.1f", log2(st[V_FMAC1].bound));
  else
    printf(" | -");
  printf("\n");
}

// Ogita, Rump and Oishi, "Accurate sum and dot product", Algorithm 6.1 (GenDot), in
// binary32 with the exact dot product of the generated terms.
static void gendot(float *x, float *y, int n, double cond) {
  int n2 = n / 2;
  double b = log2(cond);
  for (int i = 0; i < n2; i++) {
    int e = (int)lround(urand() * b / 2);
    if (i == 0) e = (int)lround(b / 2) + 1;
    if (i == n2 - 1) e = 0;
    x[i] = (float)ldexp(2 * urand() - 1, e);
    y[i] = (float)ldexp(2 * urand() - 1, e);
  }
  for (int i = n2; i < n; i++) {
    int e = (int)lround(b / 2 * (1.0 - (double)(i - n2) / (n - n2 - 1)));
    x[i] = (float)ldexp(2 * urand() - 1, e);
    exact_dot(x, y, i, tmp);
    y[i] = (float)((ldexp(2 * urand() - 1, e) - mpfr_get_d(tmp, MPFR_RNDN)) / x[i]);
  }
  for (int i = n - 1; i > 0; i--) {  // random order
    int j = (int)(urand() * (i + 1));
    float t = x[i];
    x[i] = x[j];
    x[j] = t;
    t = y[i];
    y[i] = y[j];
    y[j] = t;
  }
}

// Blocks of 16: two large products cancelled two products later (same accumulator)
// down to a few ulps, then small products.
static void cancel(float *a, float *b, int n) {
  for (int i = 0; i < n; i += 16) {
    for (int k = 0; k < 2 && i + k + 2 < n; k++) {
      float big = (float)ldexp(1 + urand(), 20);
      a[i + k] = big;
      b[i + k] = 1;
      a[i + k + 2] = -(big - (float)ldexp(1 + (int)(urand() * 8), 20 - 23));
      b[i + k + 2] = 1;
    }
    for (int k = 4; k < 16 && i + k < n; k++) {
      a[i + k] = (float)(nrand() * 0x1p-10);
      b[i + k] = (float)(1 + urand());
    }
  }
}

int main(void) {
  mpfr_init2(exact_acc, 1200);
  mpfr_init2(tmp, 1200);
  for (int v = 0; v < 3; v++) {
    mac[v] = ieee754_mac_new(32, 8, 0, 0);
    ieee754_mac_set_step(mac[v], vstep[v]);
  }
  int nmax = 100000;
  float *a = malloc(nmax * sizeof *a), *b = malloc(nmax * sizeof *b);

  printf("binary32, round to nearest even; per variant: max ulp, mean ulp, %% correctly rounded\n");
  printf("%-7s %-11s", "stream", "param");
  for (int v = 0; v < NV; v++) printf(" | %-27s", vname[v]);
  printf(" | fmac-1 bound\n");

  static const int dot_n[] = {16, 64, 256, 1024, 4096};
  for (int s = 0; s < 2; s++) {
    for (int k = 0; k < 5; k++) {
      int n = dot_n[k], trials = 200000 / n < 50 ? 50 : 200000 / n;
      stat st[NV] = {0};
      for (int t = 0; t < trials; t++) {
        for (int i = 0; i < n; i++) {
          if (s == 0) {
            a[i] = (float)nrand();
            b[i] = (float)nrand();
          } else {
            double x = nrand();
            a[i] = (float)(x > 0 ? x : 0);
            b[i] = (float)(0.05 * nrand());
          }
        }
        run(a, b, n, st);
      }
      char p[32];
      snprintf(p, sizeof p, "n=%d", n);
      report(s == 0 ? "normal" : "relu", p, st);
    }
  }

  static const int sum_n[] = {1000, 10000, 100000};
  for (int k = 0; k < 3; k++) {
    int n = sum_n[k], trials = 2000000 / n;
    stat st[NV] = {0};
    for (int t = 0; t < trials; t++) {
      for (int i = 0; i < n; i++) {
        a[i] = (float)urand();
        b[i] = 1;
      }
      run(a, b, n, st);
    }
    char p[32];
    snprintf(p, sizeof p, "n=%d", n);
    report("sum", p, st);
  }

  static const double conds[] = {1e3, 1e6, 1e9, 1e12};
  for (int k = 0; k < 4; k++) {
    int n = 100;
    stat st[NV] = {0};
    for (int t = 0; t < 2000; t++) {
      gendot(a, b, n, conds[k]);
      run(a, b, n, st);
    }
    char p[32];
    snprintf(p, sizeof p, "c=%.0e", conds[k]);
    report("gendot", p, st);
  }

  static const int cancel_n[] = {16, 256, 4096};
  for (int k = 0; k < 3; k++) {
    int n = cancel_n[k], trials = 2000000 / n;
    stat st[NV] = {0};
    for (int t = 0; t < trials; t++) {
      cancel(a, b, n);
      run(a, b, n, st);
    }
    char p[32];
    snprintf(p, sizeof p, "n=%d", n);
    report("cancel", p, st);
  }

  for (int v = 0; v < 3; v++) ieee754_mac_free(mac[v]);
  free(a);
  free(b);
  mpfr_clear(exact_acc);
  mpfr_clear(tmp);
  return 0;
}
