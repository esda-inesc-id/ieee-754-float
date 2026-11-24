// Accuracy of the model math library against the host libm.
//
// usage: math_accuracy [samples]
//
// binary16 is swept exhaustively; binary32 and binary64 use random operands, with
// samples per function in binary32 and samples/5 in binary64 (default 1000000).
// Errors are in ulps of the format against the long double result of libm.
// Returns 1 if a special case fails or an error exceeds MAX_ULP.

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ieee754_math.h"
#include "ieee754_model.h"

#define MAX_ULP 1.0

typedef uint64_t (*model_fn)(uint64_t, int, int);
typedef long double (*ref_fn)(long double);

typedef struct {
  const char *name;
  model_fn model;
  ref_fn ref;
} function;

typedef struct {
  int data_w, exp_w, f_w, bias;
} format;

static int failures = 0;
static uint64_t state = 0x9E3779B97F4A7C15ull;

static uint64_t rand64(void) {
  state ^= state << 13;
  state ^= state >> 7;
  state ^= state << 17;
  return state;
}

static format make_format(int data_w, int exp_w) {
  format f = {data_w, exp_w, data_w - exp_w - 1, (1 << (exp_w - 1)) - 1};
  return f;
}

static uint64_t data_mask(const format *f) {
  return f->data_w == 64 ? ~0ull : (1ull << f->data_w) - 1;
}

static long double decode(const format *f, uint64_t x) {
  int field = (int)(x >> f->f_w) & ((1 << f->exp_w) - 1);
  uint64_t frac = x & ((1ull << f->f_w) - 1);
  long double v;
  if (field == (1 << f->exp_w) - 1) {
    v = frac ? NAN : INFINITY;
  } else if (field == 0) {
    v = ldexpl((long double)frac, 1 - f->bias - f->f_w);
  } else {
    v = ldexpl((long double)(frac | (1ull << f->f_w)), field - f->bias - f->f_w);
  }
  return x >> (f->data_w - 1) & 1 ? -v : v;
}

// Error of x in ulps of the format at ref.
static long double ulp_error(const format *f, uint64_t x, long double ref) {
  long double v = decode(f, x);
  if (isnan(ref)) return isnan(v) ? 0 : INFINITY;
  if (isnan(v)) return INFINITY;
  int e;
  frexpl(ref, &e);
  if (ref == 0) e = 2 - f->bias;
  if (e - 1 < 1 - f->bias) e = 2 - f->bias;
  long double ulp = ldexpl(1.0L, e - 1 - f->f_w);
  long double max = ldexpl(2.0L - ldexpl(1.0L, -f->f_w), f->bias);
  if (isinf(v)) {
    long double limit = max + ldexpl(1.0L, f->bias - f->f_w - 1);
    return (v > 0 ? ref >= limit : ref <= -limit) ? 0 : INFINITY;
  }
  if (isinf(ref)) return INFINITY;
  return fabsl(v - ref) / ulp;
}

static void expect(int condition, const char *name) {
  if (!condition) {
    fprintf(stderr, "FAILED: %s\n", name);
    failures++;
  }
}

static uint64_t from_double(const format *f, double v) {
  return ieee754_from_double(v, f->data_w, f->exp_w);
}

static void special_cases(const format *f) {
  int w = f->data_w, e = f->exp_w;
  uint64_t one = from_double(f, 1), zero = 0, nzero = 1ull << (w - 1);
  uint64_t inf = from_double(f, INFINITY), ninf = from_double(f, -INFINITY);
  uint64_t nan = from_double(f, NAN), neg = from_double(f, -2);
  expect(ieee754_fabs(neg, w, e) == from_double(f, 2), "fabs");
  expect(ieee754_sqrt(nzero, w, e) == nzero, "sqrt(-0)");
  expect(ieee754_sqrt(zero, w, e) == zero, "sqrt(0)");
  expect(ieee754_sqrt(neg, w, e) == nan, "sqrt(-2)");
  expect(ieee754_sqrt(inf, w, e) == inf, "sqrt(inf)");
  expect(ieee754_sqrt(ninf, w, e) == nan, "sqrt(-inf)");
  expect(ieee754_sqrt(nan, w, e) == nan, "sqrt(nan)");
  expect(ieee754_sqrt(from_double(f, 4), w, e) == from_double(f, 2), "sqrt(4)");
  expect(ieee754_exp(zero, w, e) == one && ieee754_exp(nzero, w, e) == one, "exp(0)");
  expect(ieee754_exp(inf, w, e) == inf, "exp(inf)");
  expect(ieee754_exp(ninf, w, e) == zero, "exp(-inf)");
  expect(ieee754_exp(nan, w, e) == nan, "exp(nan)");
  expect(ieee754_exp(from_double(f, 1e6), w, e) == inf, "exp overflow");
  expect(ieee754_exp(from_double(f, -1e6), w, e) == zero, "exp underflow");
  expect(ieee754_log(one, w, e) == zero, "log(1)");
  expect(ieee754_log(zero, w, e) == ninf && ieee754_log(nzero, w, e) == ninf, "log(0)");
  expect(ieee754_log(neg, w, e) == nan, "log(-2)");
  expect(ieee754_log(inf, w, e) == inf, "log(inf)");
  expect(ieee754_log(ninf, w, e) == nan, "log(-inf)");
  expect(ieee754_log(nan, w, e) == nan, "log(nan)");
}

static long double ref_sqrt(long double x) { return sqrtl(x); }
static long double ref_exp(long double x) { return expl(x); }
static long double ref_log(long double x) { return logl(x); }

static const function functions[] = {
    {"sqrt", ieee754_sqrt, ref_sqrt},
    {"exp", ieee754_exp, ref_exp},
    {"log", ieee754_log, ref_log},
};

// Operand i of a sweep: all encodings for binary16; otherwise random positive encodings
// for sqrt and log, and for exp half random encodings with |x| < 2**8 and half uniform
// over the range where the result is finite and non-zero.
static uint64_t operand(const format *f, const function *fn, long i, int exhaustive) {
  if (exhaustive) return (uint64_t)i;
  uint64_t bits = rand64() & data_mask(f);
  if (fn->model != ieee754_exp) return bits & (data_mask(f) >> 1);
  if (i & 1) {
    int field = (int)(bits >> f->f_w) & ((1 << f->exp_w) - 1);
    if (field > f->bias + 7) bits ^= (uint64_t)(field ^ (f->bias + 7)) << f->f_w;
    return bits;
  }
  double lo = (1 - f->bias - f->f_w - 1) * 0.6931471805599453;
  double hi = (f->bias + 1) * 0.6931471805599453;
  return from_double(f, lo + (hi - lo) * ((double)(rand64() >> 11) / 9007199254740992.0));
}

static void sweep(int data_w, int exp_w, long samples, int exhaustive) {
  format f = make_format(data_w, exp_w);
  special_cases(&f);
  for (size_t j = 0; j < sizeof functions / sizeof functions[0]; j++) {
    const function *fn = &functions[j];
    long double worst = 0;
    uint64_t worst_x = 0;
    for (long i = 0; i < samples; i++) {
      uint64_t x = operand(&f, fn, i, exhaustive);
      long double err = ulp_error(&f, fn->model(x, data_w, exp_w), fn->ref(decode(&f, x)));
      if (err > worst) {
        worst = err;
        worst_x = x;
      }
    }
    printf("binary%d %-4s %8ld values: max error %.3Lf ulp at 0x%0*llx\n", data_w, fn->name,
           samples, worst, data_w / 4, (unsigned long long)worst_x);
    if (worst > MAX_ULP) {
      fprintf(stderr, "FAILED: binary%d %s exceeds %.1f ulp\n", data_w, fn->name, MAX_ULP);
      failures++;
    }
  }
}

int main(int argc, char **argv) {
  long samples = argc > 1 ? atol(argv[1]) : 1000000;
  sweep(16, 5, 1 << 16, 1);
  sweep(32, 8, samples, 0);
  sweep(64, 11, samples / 5, 0);
  if (failures) {
    fprintf(stderr, "%d failures\n", failures);
    return 1;
  }
  printf("math accuracy tests passed\n");
  return 0;
}
