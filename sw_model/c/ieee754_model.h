// Bit-accurate C model of the IEEE-754 units: fadd, fmul, fdiv, fmac, ffma and fpu.
//
// Operands and results are raw encodings in the low data_w bits of a uint64_t.
// Rounding follows the mode set by ieee754_set_rounding, to nearest ties to even by
// default. There are no exception flags.
// Every NaN result is the quiet NaN with sign 0 and only the top fraction bit set.
//
// Supported formats: 6 <= data_w - exp_w <= 53, 2 <= exp_w <= 11, data_w <= 64. fmac and ffma
// also take precisions data_w - exp_w from 2 (FP8 E5M2 and E4M3, FP4 E2M1) to 113, with
// 2 <= exp_w <= 15 and data_w <= 128 (binary128), through the _w functions, whose
// operands and results are raw encodings in the low data_w bits of an ieee754_u128.

#ifndef IEEE754_MODEL_H
#define IEEE754_MODEL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned __int128 ieee754_u128;

// Returns 1 if the format is supported by every unit.
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

// Encodings of the special values, for later operations and mac units created after the
// call. IEEE (default): infinities and NaNs as in IEEE 754. FN (OCP FP8 E4M3): no
// infinities; the largest exponent holds normal numbers and the only NaN has every
// exponent and fraction bit set. FINITE (OCP FP4 E2M1): no infinities and no NaN.
// Without infinities, overflow saturates to the largest finite number in every rounding
// mode; without NaN, an invalid operation also gives the largest finite number.
enum { IEEE754_SPECIAL_IEEE, IEEE754_SPECIAL_FN, IEEE754_SPECIAL_FINITE };
void ieee754_set_special(int kind);
int ieee754_get_special(void);

// Sets the rounding mode of later add, sub, mul, div and fmac products (low 3 bits of mode).
void ieee754_set_rounding(int mode);
int ieee754_get_rounding(void);

// fadd, fmul and fdiv; fpu funct 0 to 3 is add, sub, mul and div.
uint64_t ieee754_add(uint64_t a, uint64_t b, int data_w, int exp_w);
uint64_t ieee754_sub(uint64_t a, uint64_t b, int data_w, int exp_w);
uint64_t ieee754_mul(uint64_t a, uint64_t b, int data_w, int exp_w);
uint64_t ieee754_div(uint64_t a, uint64_t b, int data_w, int exp_w);

// ffma: a*b + c, rounded once. Returns 0 for an unsupported format.
uint64_t ieee754_fma(uint64_t a, uint64_t b, uint64_t c, int data_w, int exp_w);
ieee754_u128 ieee754_fma_w(ieee754_u128 a, ieee754_u128 b, ieee754_u128 c, int data_w, int exp_w);

// Conversions from and to binary64, always rounding to nearest even.
uint64_t ieee754_from_double(double value, int data_w, int exp_w);
double ieee754_to_double(uint64_t bits, int data_w, int exp_w);
ieee754_u128 ieee754_from_double_w(double value, int data_w, int exp_w);
double ieee754_to_double_w(ieee754_u128 bits, int data_w, int exp_w);

// Streaming fmac: a clocked model of the mac pipeline.
typedef struct ieee754_mac ieee754_mac;

// Returns NULL if the format is unsupported or the accumulator exceeds 256 bits
// (lguard_w + rguard_w + 2 * (data_w - exp_w) + 5 <= 256).
ieee754_mac *ieee754_mac_new(int data_w, int exp_w, int lguard_w, int rguard_w);
void ieee754_mac_free(ieee754_mac *mac);

// Architecture studies only: the largest left shift of the accumulator normalization per
// accumulation. The RTL shifts by 1 (the default); a step of at least the accumulator width
// normalizes fully every cycle.
void ieee754_mac_set_step(ieee754_mac *mac, int step);

// Architecture studies only: how the accumulator drops its EXTRA low bits on feedback. The
// RTL rounds to nearest, ties to even (the default).
enum {
  IEEE754_FB_ODD,       // last kept bit |= OR of the dropped bits
  IEEE754_FB_TRUNC,     // truncate
  IEEE754_FB_FIRST,     // last kept bit |= first dropped bit
  IEEE754_FB_NEAR_UP,   // nearest, ties up
  IEEE754_FB_NEAR_EVEN  // nearest, ties to even
};
void ieee754_mac_set_feedback(ieee754_mac *mac, int fb);

// Architecture studies only: since the unit was created, the products accumulated, those
// aligned with an accumulator not yet fully normalized, and the sum of its missing
// normalization bits.
void ieee754_mac_stats(const ieee754_mac *mac, long *accs, long *lagged, long *lag_bits);

// Applies one product of the current stream. The stream rounds in the mode current at
// its last product, as fmac samples rnd_mode with it.
void ieee754_mac_push(ieee754_mac *mac, uint64_t a, uint64_t b);

// Ends the stream and returns its sum; returns +0 for an empty stream.
uint64_t ieee754_mac_result(ieee754_mac *mac);

// push and result for any format, up to binary128
void ieee754_mac_push_w(ieee754_mac *mac, ieee754_u128 a, ieee754_u128 b);
ieee754_u128 ieee754_mac_result_w(ieee754_mac *mac);

#ifdef __cplusplus
}
#endif

#endif
