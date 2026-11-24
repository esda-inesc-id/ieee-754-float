// Math functions built on the bit-accurate model.
//
// Each function uses only ieee754_add, ieee754_sub, ieee754_mul and ieee754_div of the
// model plus exact bit operations on the encodings; there is no host floating-point
// arithmetic. Operands and results are raw encodings in the low data_w bits of a
// uint64_t, as in ieee754_model.h. Constants are binary64 bit patterns rounded to the
// format. NaN results are the model's quiet NaN. The functions round to nearest, ties to
// even, whatever the mode set by ieee754_set_rounding.

#ifndef IEEE754_MATH_H
#define IEEE754_MATH_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// |a|: clears the sign bit.
uint64_t ieee754_fabs(uint64_t a, int data_w, int exp_w);

// Square root; sqrt(-0) is -0 and a negative operand gives NaN.
uint64_t ieee754_sqrt(uint64_t a, int data_w, int exp_w);

// e**a; overflows to +inf and underflows to +0.
uint64_t ieee754_exp(uint64_t a, int data_w, int exp_w);

// Natural logarithm; log(+-0) is -inf and a negative operand gives NaN.
uint64_t ieee754_log(uint64_t a, int data_w, int exp_w);

#ifdef __cplusplus
}
#endif

#endif
