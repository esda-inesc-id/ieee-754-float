// Bit-accurate C model of the IEEE-754 units: fadd, fmul, fdiv, fmac and fpu.
//
// Operands and results are raw encodings in the low data_w bits of a uint64_t.
// Rounding follows the mode set by ieee754_set_rounding, to nearest ties to even by
// default. There are no exception flags.
// Every NaN result is the quiet NaN with sign 0 and only the top fraction bit set.
//
// Supported formats: 6 <= data_w - exp_w <= 53, 2 <= exp_w <= 11, data_w <= 64.

#ifndef IEEE754_MODEL_H
#define IEEE754_MODEL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Returns 1 if the format is supported.
int ieee754_format_ok(int data_w, int exp_w);

// Rounding modes, encoded as the rnd_mode input of the units (RISC-V frm).
// Values 5 to 7 round to nearest, ties to even, as in the RTL.
enum {
  IEEE754_RNE = 0,  // to nearest, ties to even (default)
  IEEE754_RTZ = 1,  // toward zero
  IEEE754_RDN = 2,  // toward -infinity
  IEEE754_RUP = 3,  // toward +infinity
  IEEE754_RMM = 4   // to nearest, ties away from zero
};

// Sets the rounding mode of later add, sub, mul, div and fmac products (low 3 bits of mode).
void ieee754_set_rounding(int mode);
int ieee754_get_rounding(void);

// fadd, fmul and fdiv; fpu funct 0 to 3 is add, sub, mul and div.
uint64_t ieee754_add(uint64_t a, uint64_t b, int data_w, int exp_w);
uint64_t ieee754_sub(uint64_t a, uint64_t b, int data_w, int exp_w);
uint64_t ieee754_mul(uint64_t a, uint64_t b, int data_w, int exp_w);
uint64_t ieee754_div(uint64_t a, uint64_t b, int data_w, int exp_w);

// Conversions from and to binary64, always rounding to nearest even.
uint64_t ieee754_from_double(double value, int data_w, int exp_w);
double ieee754_to_double(uint64_t bits, int data_w, int exp_w);

// Streaming fmac: a clocked model of the mac pipeline.
typedef struct ieee754_mac ieee754_mac;

// Returns NULL if the format is unsupported or the accumulator exceeds 128 bits
// (lguard_w + rguard_w + 2 * (data_w - exp_w) + 5 <= 128).
ieee754_mac *ieee754_mac_new(int data_w, int exp_w, int lguard_w, int rguard_w);
void ieee754_mac_free(ieee754_mac *mac);

// Applies one product of the current stream. The stream rounds in the mode current at
// its last product, as fmac samples rnd_mode with it.
void ieee754_mac_push(ieee754_mac *mac, uint64_t a, uint64_t b);

// Ends the stream and returns its sum; returns +0 for an empty stream.
uint64_t ieee754_mac_result(ieee754_mac *mac);

#ifdef __cplusplus
}
#endif

#endif
