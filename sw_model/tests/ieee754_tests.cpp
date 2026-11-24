// Self-checking tests of the C++ type, the streaming MAC and the rounding modes.
//
// usage: ieee754_tests

#include <fenv.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"
#include "ieee754.h"

static int failures = 0;

static void expect(bool condition, const char *name) {
  if (!condition) {
    fprintf(stderr, "FAILED: %s\n", name);
    failures++;
  }
}

static uint32_t float_bits(float value) {
  uint32_t bits;
  memcpy((void *)&bits, (const void *)&value, sizeof bits);
  return bits;
}

static bool same(const Ieee754 &value, float reference) {
  if (reference != reference) return (double)value != (double)value;
  return value.bits() == float_bits(reference);
}

static void conversion_tests() {
  expect((double)Ieee754(0.5) == 0.5, "double conversion");
  expect((float)Ieee754(78.34F) == 78.34F, "float conversion");
  expect((int)Ieee754(400) == 400, "int conversion");
  expect((int)Ieee754(37.48) == 37, "int truncation");
  expect(Ieee754(1e300).bits() == 0x7F800000u, "overflow to infinity");
  expect(Ieee754(1e-60).bits() == 0, "underflow to zero");
  expect(Ieee754(-0.0).bits() == 0x80000000u, "negative zero");

  srand(754);
  for (int i = 0; i < 200000; i++) {
    double value = ldexp((double)rand32() * (double)rand32(), rand() % 400 - 260);
    expect(same(Ieee754(value), (float)value), "conversion matches the host");
  }
}

static void arithmetic_tests() {
  Ieee754 a = 1.0;
  Ieee754 b = 2.0F;
  Ieee754 c;

  expect((double)(c++) == 0.0 && (double)c == 1.0, "post-increment");
  expect((double)(++c) == 2.0, "pre-increment");
  expect((double)(c--) == 2.0 && (double)(--c) == 0.0, "decrement");
  expect((double)(a + b) == 3.0 && (double)(b + 4.0) == 6.0, "add");
  expect((double)(7 + b) == 9.0 && (double)(3.0F + b) == 5.0, "add with a left constant");
  expect((double)(a - b) == -1.0 && (double)(4.0 - b) == 2.0, "sub");
  expect((double)(-b) == -2.0, "negate");
  expect((double)(b * 7) == 14.0 && (double)(4.0 * b) == 8.0, "mul");
  expect((double)(a / b) == 0.5 && (double)(7 / b) == 3.5, "div");
  c = 3;
  c += b;
  c -= a;
  c *= b;
  c /= 4;
  expect((double)c == 2.0, "compound assignment");

  for (int i = 0; i < 200000; i++) {
    uint32_t x = (uint32_t)rand32();
    uint32_t y = (uint32_t)rand32();
    float fx, fy;
    memcpy((void *)&fx, (const void *)&x, sizeof x);
    memcpy((void *)&fy, (const void *)&y, sizeof y);
    Ieee754 ex = Ieee754::from_bits(x);
    Ieee754 ey = Ieee754::from_bits(y);
    expect(same(ex + ey, fx + fy), "add matches the host");
    expect(same(ex - ey, fx - fy), "sub matches the host");
    expect(same(ex * ey, fx * fy), "mul matches the host");
    expect(same(ex / ey, fx / fy), "div matches the host");
  }
}

static void comparator_tests() {
  Ieee754 one = 1;
  Ieee754 two = 2;
  Ieee754 nan = Ieee754::from_bits(0x7FC00000u);
  expect(one < two && one <= two && two > one && two >= one, "ordering");
  expect(one != two && two == 2 && 2 == two, "equality");
  expect(!(nan == nan) && nan != nan && !(nan < one), "NaN comparisons");
  expect(Ieee754(0.0) == Ieee754(-0.0), "signed zeros compare equal");
}

static void memory_tests() {
  const int n = 10;
  Ieee754 *vec = (Ieee754 *)calloc(n, sizeof(Ieee754));
  expect((double)vec[n - 1] == 0.0, "calloc gives zero");

  double vec_d[n];
  float vec_f[n];
  int vec_i[n];
  for (int i = 0; i < n; i++) {
    vec_d[i] = i + 0.5;
    vec_f[i] = i + 0.25F;
    vec_i[i] = i;
  }
  memcpy(vec, vec_d, sizeof vec_d);
  expect((double)vec[3] == 3.5, "memcpy from double");
  memcpy(vec, vec_f, sizeof vec_f);
  expect((double)vec[3] == 3.25, "memcpy from float");
  memcpy(vec, vec_i, sizeof vec_i);
  expect((double)vec[3] == 3.0, "memcpy from int");
  free(vec);
}

static void mac_tests() {
  Ieee754Mac mac;

  mac.push(Ieee754(1.5), Ieee754(2.0));
  mac.push(Ieee754(-1.0), Ieee754(1.0));
  expect((double)mac.result() == 2.0, "MAC of two products");

  mac.push(Ieee754(-0.0), Ieee754(1.0));
  expect(mac.result().bits() == 0x80000000u, "MAC keeps -0");

  mac.push(Ieee754(INFINITY), Ieee754(0.0));
  expect((double)mac.result() != (double)mac.result(), "MAC of infinity times zero");
}

static Ieee754 sp(uint32_t bits) { return Ieee754::from_bits(bits); }

static void rounding_tests() {
  expect(ieee754_get_rounding() == IEEE754_RNE, "RNE is the default mode");

  // The host has every mode but RMM
  static const int modes[4][2] = {{IEEE754_RNE, FE_TONEAREST},
                                  {IEEE754_RTZ, FE_TOWARDZERO},
                                  {IEEE754_RDN, FE_DOWNWARD},
                                  {IEEE754_RUP, FE_UPWARD}};
  for (const auto &mode : modes) {
    Ieee754Rounding rounding(mode[0]);
    fesetround(mode[1]);
    bool ok = true;
    for (int i = 0; i < 50000; i++) {
      uint32_t x = (uint32_t)rand32();
      uint32_t y = (uint32_t)rand32();
      volatile float fx, fy;
      memcpy((void *)&fx, (const void *)&x, sizeof x);
      memcpy((void *)&fy, (const void *)&y, sizeof y);
      ok = ok && same(sp(x) + sp(y), fx + fy) && same(sp(x) - sp(y), fx - fy) &&
           same(sp(x) * sp(y), fx * fy) && same(sp(x) / sp(y), fx / fy);
    }
    fesetround(FE_TONEAREST);
    expect(ok, "operations match the host in its rounding modes");
  }
  expect(ieee754_get_rounding() == IEEE754_RNE, "Ieee754Rounding restores the mode");

  Ieee754 one = 1.0;
  Ieee754 tie = Ieee754::from_bits(0x33800000u);  // 2**-24, half a unit of 1.0
  Ieee754 max = Ieee754::from_bits(0x7F7FFFFFu);
  {
    Ieee754Rounding rounding(IEEE754_RMM);
    expect((one + tie).bits() == 0x3F800001u, "RMM rounds a tie away from zero");
    expect((max * 2).bits() == 0x7F800000u, "RMM overflows to infinity");
  }
  expect((one + tie).bits() == 0x3F800000u, "RNE rounds a tie to even");
  {
    Ieee754Rounding rounding(IEEE754_RTZ);
    expect((max * 2).bits() == 0x7F7FFFFFu && (-max * 2).bits() == 0xFF7FFFFFu,
           "RTZ overflows to the largest finite number");
  }
  {
    Ieee754Rounding rounding(IEEE754_RDN);
    expect((max * 2).bits() == 0x7F7FFFFFu && (-max * 2).bits() == 0xFF800000u,
           "RDN overflow");
    expect((one - one).bits() == 0x80000000u, "RDN gives -0 for x - x");
    expect(sqrt(Ieee754(2.0)).bits() == 0x3FB504F3u, "math functions round to nearest");
    Ieee754Mac mac;
    mac.push(one, one);
    mac.push(-one, one);
    expect(mac.result().bits() == 0x80000000u, "RDN gives -0 for an exact MAC cancellation");
    mac.push(Ieee754(0.0), one);
    expect(mac.result().bits() == 0, "MAC of +0 products is +0 in RDN");
  }
  {
    Ieee754Rounding rounding(IEEE754_RUP);
    expect((-max * 2).bits() == 0xFF7FFFFFu && (one - one).bits() == 0, "RUP");
    Ieee754Mac mac;
    mac.push(tie, one);
    ieee754_set_rounding(IEEE754_RTZ);
    mac.push(one, one);
    expect(mac.result().bits() == 0x3F800000u, "MAC rounds in the mode of its last product");
  }
}

int main() {
  conversion_tests();
  arithmetic_tests();
  comparator_tests();
  memory_tests();
  mac_tests();
  rounding_tests();

  printf("ieee754_tests: %s (%d failures)\n", failures ? "FAIL" : "PASS", failures);
  return failures != 0;
}
