// C++ floating-point type on top of the C model.
//
// Ieee754 holds one encoding of the format IEEE754_DATA_W / IEEE754_EXP_W. Add, subtract,
// multiply and divide run on the model; math functions go through binary64.
// Ieee754Mac is the streaming fmac.

#ifndef IEEE754_H
#define IEEE754_H

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <iostream>
#include <type_traits>

#include "ieee754_model.h"

#ifndef IEEE754_DATA_W
#define IEEE754_DATA_W 32
#endif
#ifndef IEEE754_EXP_W
#define IEEE754_EXP_W 8
#endif

#define IEEE754_SP_DATA_W 32
#define IEEE754_SP_EXP_W 8
#define IEEE754_SP_F_W 23
#define IEEE754_SP_BIAS 127
#define IEEE754_DP_DATA_W 64
#define IEEE754_DP_EXP_W 11
#define IEEE754_DP_F_W 52
#define IEEE754_DP_BIAS 1023

template <class T>
using EnableIfArithmetic = typename std::enable_if<std::is_arithmetic<T>::value, int>::type;

class Ieee754 {
 public:
  Ieee754() : bits_(0) {}

  template <class T, EnableIfArithmetic<T> = 0>
  Ieee754(T value) : bits_(ieee754_from_double((double)value, IEEE754_DATA_W, IEEE754_EXP_W)) {}

  static Ieee754 from_bits(uint64_t bits) {
    Ieee754 res;
    res.bits_ = bits;
    return res;
  }

  uint64_t bits() const { return bits_; }

  double to_double() const { return ieee754_to_double(bits_, IEEE754_DATA_W, IEEE754_EXP_W); }

  template <class T, EnableIfArithmetic<T> = 0>
  operator T() const {
    return (T)to_double();
  }

  Ieee754 operator-() const { return from_bits(bits_ ^ ((uint64_t)1 << (IEEE754_DATA_W - 1))); }

  Ieee754 &operator+=(const Ieee754 &other) { return *this = *this + other; }
  Ieee754 &operator-=(const Ieee754 &other) { return *this = *this - other; }
  Ieee754 &operator*=(const Ieee754 &other) { return *this = *this * other; }
  Ieee754 &operator/=(const Ieee754 &other) { return *this = *this / other; }

  Ieee754 &operator++() { return *this += Ieee754(1); }
  Ieee754 &operator--() { return *this -= Ieee754(1); }

  Ieee754 operator++(int) {
    Ieee754 old = *this;
    ++*this;
    return old;
  }

  Ieee754 operator--(int) {
    Ieee754 old = *this;
    --*this;
    return old;
  }

  friend Ieee754 operator+(const Ieee754 &a, const Ieee754 &b) {
    return from_bits(ieee754_add(a.bits_, b.bits_, IEEE754_DATA_W, IEEE754_EXP_W));
  }

  friend Ieee754 operator-(const Ieee754 &a, const Ieee754 &b) {
    return from_bits(ieee754_sub(a.bits_, b.bits_, IEEE754_DATA_W, IEEE754_EXP_W));
  }

  friend Ieee754 operator*(const Ieee754 &a, const Ieee754 &b) {
    return from_bits(ieee754_mul(a.bits_, b.bits_, IEEE754_DATA_W, IEEE754_EXP_W));
  }

  friend Ieee754 operator/(const Ieee754 &a, const Ieee754 &b) {
    return from_bits(ieee754_div(a.bits_, b.bits_, IEEE754_DATA_W, IEEE754_EXP_W));
  }

  friend bool operator<(const Ieee754 &a, const Ieee754 &b) {
    return a.to_double() < b.to_double();
  }
  friend bool operator<=(const Ieee754 &a, const Ieee754 &b) {
    return a.to_double() <= b.to_double();
  }
  friend bool operator>(const Ieee754 &a, const Ieee754 &b) {
    return a.to_double() > b.to_double();
  }
  friend bool operator>=(const Ieee754 &a, const Ieee754 &b) {
    return a.to_double() >= b.to_double();
  }
  friend bool operator==(const Ieee754 &a, const Ieee754 &b) {
    return a.to_double() == b.to_double();
  }
  friend bool operator!=(const Ieee754 &a, const Ieee754 &b) {
    return a.to_double() != b.to_double();
  }

  friend std::ostream &operator<<(std::ostream &output, const Ieee754 &value) {
    return output << value.to_double();
  }

  friend std::istream &operator>>(std::istream &input, Ieee754 &value) {
    double parsed;
    input >> parsed;
    value = Ieee754(parsed);
    return input;
  }

 private:
  uint64_t bits_;
};

// Mixed operations with built-in arithmetic types.
#define IEEE754_MIXED_OP(RET, OP)                       \
  template <class T, EnableIfArithmetic<T> = 0>         \
  inline RET operator OP(const Ieee754 &a, T b) {       \
    return a OP Ieee754(b);                             \
  }                                                     \
  template <class T, EnableIfArithmetic<T> = 0>         \
  inline RET operator OP(T a, const Ieee754 &b) {       \
    return Ieee754(a) OP b;                             \
  }

IEEE754_MIXED_OP(Ieee754, +)
IEEE754_MIXED_OP(Ieee754, -)
IEEE754_MIXED_OP(Ieee754, *)
IEEE754_MIXED_OP(Ieee754, /)
IEEE754_MIXED_OP(bool, <)
IEEE754_MIXED_OP(bool, <=)
IEEE754_MIXED_OP(bool, >)
IEEE754_MIXED_OP(bool, >=)
IEEE754_MIXED_OP(bool, ==)
IEEE754_MIXED_OP(bool, !=)

#undef IEEE754_MIXED_OP

// Math functions, evaluated in binary64.
inline Ieee754 cos(const Ieee754 &x) { return cos(x.to_double()); }
inline Ieee754 sin(const Ieee754 &x) { return sin(x.to_double()); }
inline Ieee754 acos(const Ieee754 &x) { return acos(x.to_double()); }
inline Ieee754 exp(const Ieee754 &x) { return exp(x.to_double()); }
inline Ieee754 log(const Ieee754 &x) { return log(x.to_double()); }
inline Ieee754 log2(const Ieee754 &x) { return log2(x.to_double()); }
inline Ieee754 sqrt(const Ieee754 &x) { return sqrt(x.to_double()); }
inline Ieee754 ceil(const Ieee754 &x) { return ceil(x.to_double()); }
inline Ieee754 floor(const Ieee754 &x) { return floor(x.to_double()); }
inline Ieee754 frexp(const Ieee754 &x, int *e) { return frexp(x.to_double(), e); }
inline Ieee754 pow(const Ieee754 &x, const Ieee754 &y) { return pow(x.to_double(), y.to_double()); }
inline Ieee754 pow(const Ieee754 &x, double y) { return pow(x.to_double(), y); }
inline Ieee754 pow(double x, const Ieee754 &y) { return pow(x, y.to_double()); }

inline Ieee754 fabs(const Ieee754 &x) {
  return Ieee754::from_bits(x.bits() & ~((uint64_t)1 << (IEEE754_DATA_W - 1)));
}

// Element-wise conversion into an Ieee754 array; n is the source size in bytes.
template <class T, EnableIfArithmetic<T> = 0>
inline void *memcpy(Ieee754 *dst, const T *src, size_t n) {
  n /= sizeof(T);
  while (n--) dst[n] = Ieee754(src[n]);
  return dst;
}

class Ieee754Mac {
 public:
  explicit Ieee754Mac(int lguard_w = 0, int rguard_w = 0)
      : mac_(ieee754_mac_new(IEEE754_DATA_W, IEEE754_EXP_W, lguard_w, rguard_w)) {
    if (!mac_) {
      std::cerr << "unsupported fmac configuration" << std::endl;
      exit(1);
    }
  }

  ~Ieee754Mac() { ieee754_mac_free(mac_); }

  Ieee754Mac(const Ieee754Mac &) = delete;
  Ieee754Mac &operator=(const Ieee754Mac &) = delete;

  void push(const Ieee754 &a, const Ieee754 &b) { ieee754_mac_push(mac_, a.bits(), b.bits()); }

  Ieee754 result() { return Ieee754::from_bits(ieee754_mac_result(mac_)); }

 private:
  ieee754_mac *mac_;
};

#endif
