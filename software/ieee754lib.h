#ifndef IEEE754LIB_H
#define IEEE754LIB_H

#include <stdint.h>
#include <stdio.h>

//
//     IEEE-754<FP_DATA_W, FP_EXP_W>
//
// |<------------FP_DATA_W------------>|
// |_____ ____________ ________________|
// |__S__|____EXP_____|_______F________|
// |     |            |                |
// |<-1->|<-FP_EXP_W->|<----FP_F_W---->|
//

//
// Defines
//

#define MSB(w) ((int64_t)1 << ((w) - 1))
#define MASK(width) (int64_t)(((uint128_t)1 << (width)) - 1)

#define IEEE754_DATA_W 32
#define IEEE754_EXP_W  8

#define IEEE754_BIAS(ew)      ((1 << ((ew) - 1)) - 1)
#define IEEE754_F_W(dw, ew)   ((dw) - 1 - (ew))
#define IEEE754_MAN_W(dw, ew) (IEEE754_F_W(dw, ew) + 1)
#define IEEE754_RES_W(dw, ew) (IEEE754_MAN_W(dw, ew) + 3)

#define IEEE754_EXP_MAX(ew) (((1 << (ew)) - 1) - 1)
#define IEEE754_EXP_MIN     1
#define IEEE754_EXP_INF(ew) ((1 << (ew)) - 1)
#define IEEE754_EXP_NAN(ew) IEEE754_EXP_INF(ew)
#define IEEE754_EXP_SUB     0

#define IEEE754_NAN(dw, ew)    (((int64_t)IEEE754_EXP_NAN(ew) << ((dw) - (ew) - 1)) | ((int64_t)1 << ((dw) - (ew) - 2)))
#define IEEE754_INF(s, dw, ew) (((int64_t)(s) << ((dw) - 1)) | ((int64_t)IEEE754_EXP_INF(ew) << ((dw) - (ew) - 1)))

#define IEEE754_DP_DATA_W  64
#define IEEE754_DP_EXP_W   11
#define IEEE754_DP_BIAS    IEEE754_BIAS(IEEE754_DP_EXP_W)
#define IEEE754_DP_F_W     IEEE754_F_W(IEEE754_DP_DATA_W, IEEE754_DP_EXP_W)
#define IEEE754_DP_MAN_W   IEEE754_MAN_W(IEEE754_DP_DATA_W, IEEE754_DP_EXP_W)

#define IEEE754_SP_DATA_W 32
#define IEEE754_SP_EXP_W  8
#define IEEE754_SP_BIAS   IEEE754_BIAS(IEEE754_SP_EXP_W)
#define IEEE754_SP_F_W    IEEE754_F_W(IEEE754_SP_DATA_W, IEEE754_SP_EXP_W)
#define IEEE754_SP_MAN_W  IEEE754_MAN_W(IEEE754_SP_DATA_W, IEEE754_SP_EXP_W)

#define IEEE754_W 64
#define UPK_MAN_W 64

#define _IEEE754_MAX_(dw)      ((((int64_t)IEEE754_EXP_INF(ew) - 1) << ((dw) - (ew) - 1)) | ((1 << IEEE754_F_W(dw, ew)) - 1))
#define _IEEE754_MIN_(dw)      (((int64_t)-1 << ((dw) - 1)) | (((int64_t)IEEE754_EXP_INF(ew) - 1) << ((dw) - (ew) - 1)) | ((1 << IEEE754_F_W(dw, ew)) - 1))
#define IEEE754_ZERO           0
#define _IEEE754_HALF_(dw, ew) ((((int64_t)1 << (ew - 1)) - 2) << ((dw) - (ew) - 1))
#define _IEEE754_ONE_(dw, ew)  ((((int64_t)1 << (ew - 1)) - 1) << ((dw) - (ew) - 1))
#define _IEEE754_TWO_(dw, ew)  (((int64_t)1 << (ew - 1)) << ((dw) - (ew) - 1))
#define _IEEE754_M_ONE_(dw)    (((int64_t)-1 << ((dw) - 1)) | ((((int64_t)1 << (ew - 1)) - 1) << ((dw) - (ew) - 1)))

#define IEEE754_MAX   _IEEE754_MAX_(IEEE754_DATA_W)
#define IEEE754_MIN   _IEEE754_MIN_(IEEE754_DATA_W)
#define IEEE754_HALF  _IEEE754_HALF_(IEEE754_DATA_W, IEEE754_EW)
#define IEEE754_ONE   _IEEE754_ONE_(IEEE754_DATA_W)
#define IEEE754_TWO   _IEEE754_TWO_(IEEE754_DATA_W, IEEE754_EW)
#define IEEE754_M_ONE _IEEE754_M_ONE_(IEEE754_DATA_W)

//
// Typedefs
//

typedef struct {
  uint8_t  sign;
  int32_t  exp;
  uint64_t man;
  } ieee754Unpacked;

typedef struct {
  int32_t exp;
  int64_t man;
  } ieee754Acc;

typedef int64_t ieee754;

typedef __int128 int128_t;
typedef unsigned __int128 uint128_t;

//
// Functions
//

ieee754Unpacked ieee754_unpack_(ieee754 input, int32_t dw, int32_t ew);
ieee754Unpacked ieee754_add_sub(ieee754Unpacked a, ieee754Unpacked b, uint8_t op, int32_t dw, int32_t ew);
ieee754Unpacked ieee754_mul_(ieee754Unpacked a, int32_t sca, ieee754Unpacked b, int32_t scb, int32_t dw, int32_t ew);
ieee754Unpacked ieee754_div_(ieee754Unpacked a, int32_t sca, ieee754Unpacked b, int32_t scb, int32_t dw, int32_t ew);
ieee754Unpacked ieee754_mac_(ieee754 *vec_a, int32_t sca, ieee754 *vec_b, int32_t scb, uint16_t n, int32_t dw, int32_t ew);
ieee754Unpacked ieee754_acc_(ieee754Acc *acc, ieee754Unpacked *a, int32_t sca, int32_t dw, int32_t ew);
ieee754 ieee754_pack_(ieee754Unpacked o, int32_t dw, int32_t ew);

#define _ieee754_unpack_(input, dw, ew) ieee754_unpack_(input, dw, ew)
#define _ieee754_add_(a, b, dw, ew) ieee754_pack_(ieee754_add_sub(ieee754_unpack_(a, dw, ew), ieee754_unpack_(b, dw, ew), 0, dw, ew), dw, ew)
#define _ieee754_sub_(a, b, dw, ew) ieee754_pack_(ieee754_add_sub(ieee754_unpack_(a, dw, ew), ieee754_unpack_(b, dw, ew), 1, dw, ew), dw, ew)
#define _ieee754_mul_(a, sca, b, scb, dw, ew) ieee754_pack_(ieee754_mul_(ieee754_unpack_(a, dw, ew), sca, ieee754_unpack_(b, dw, ew), scb, dw, ew), dw, ew)
#define _ieee754_div_(a, sca, b, scb, dw, ew) ieee754_pack_(ieee754_div_(ieee754_unpack_(a, dw, ew), sca, ieee754_unpack_(b, dw, ew), scb, dw, ew), dw, ew)
#define _ieee754_mac_(a, sca, b, scb, n, dw, ew) ieee754_pack_(ieee754_mac_(a, sca, b, scb, n, dw, ew), dw, ew)
#define _ieee754_acc_(acc, a, sca, dw, ew) ieee754_pack_(ieee754_acc_(acc, a, sca, dw, ew), dw, ew)
#define _ieee754_rst_acc_(acc) (*acc = {IEEE754_EXP_MIN, 0})
#define _ieee754_set_acc_(acc, val, dw, ew) ({\
  ieee754Unpacked upk = ieee754_unpack_(val, dw, ew);\
  *acc.exp = upk.exp;\
  *acc.man = upk.man << (IEEE754_RES_W(dw, ew) - 1);\
  if (upk.sign) *acc.man = -*acc.man;\
})
#define _ieee754_pack_(o, dw, ew) ieee754_pack_(o, dw, ew)

#define ieee754_unpack(input) ieee754_unpack_(input, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_add(a, b) _ieee754_add_(a, b, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_sub(a, b) _ieee754_sub_(a, b, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_mul(a, b) _ieee754_mul_(a, 0, b, 0, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_div(a, b) _ieee754_div_(a, 0, b, 0, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_mac(a, b, n) _ieee754_mac_(a, 0, b, 0, n, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_acc(acc, a) _ieee754_acc_(acc, a, 0, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_rst_acc(acc) _ieee754_rst_acc_(acc)
#define ieee754_set_acc(acc, val) _ieee754_set_acc_(acc, val, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754_pack(o) ieee754_pack_(o, IEEE754_DATA_W, IEEE754_EXP_W)

#define ieee754_neg(a, dw) (a ^ ((int64_t)-1 << ((dw) - 1)))
#define ieee754_abs(a, dw) ((a < 0)? ieee754_neg(a, dw): a)

ieee754 doubletoieee754_(double input, int32_t dw, int32_t ew);
#define floattoieee754_(input, dw, ew) doubletoieee754_((double)input, dw, ew)
double ieee754todouble_(ieee754 input, int32_t dw, int32_t ew);
#define ieee754tofloat_(input, dw, ew) (float)ieee754todouble_(input, dw, ew)
#define inttoieee754_(input, dw, ew) doubletoieee754_((double)input, dw, ew)
int64_t ieee754toint_(ieee754 input, int32_t dw, int32_t ew);

#define _doubletoieee754_(input, dw, ew) doubletoieee754_(input, dw, ew)
#define _ieee754todouble_(input, dw, ew) ieee754todouble_(input, dw, ew)
#define _floattoieee754_(input, dw, ew)  floattoieee754_(input, dw, ew)
#define _ieee754tofloat_(input, dw, ew)  ieee754tofloat_(input, dw, ew)
#define _inttoieee754_(input, dw, ew)    inttoieee754_(input, dw, ew)
#define _ieee754toint_(input, dw, ew)    ieee754toint_(input, dw, ew)

#define doubletoieee754(input) doubletoieee754_(input, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754todouble(input) ieee754todouble_(input, IEEE754_DATA_W, IEEE754_EXP_W)
#define floattoieee754(input)  floattoieee754_(input, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754tofloat(input)  ieee754tofloat_(input, IEEE754_DATA_W, IEEE754_EXP_W)
#define inttoieee754(input)    inttoieee754_(input, IEEE754_DATA_W, IEEE754_EXP_W)
#define ieee754toint(input)    ieee754toint_(input, IEEE754_DATA_W, IEEE754_EXP_W)

#define ieee754_compare(a, b, dw) ({\
  int8_t ret;\
  int64_t abs_a = ieee754_abs(a, dw);\
  int64_t abs_b = ieee754_abs(b, dw);\
  if (abs_a > abs_b) ret = 1;\
  else if (abs_a < abs_b) ret = -1;\
  else ret = 0;\
  if ((a & MSB(IEEE754_W)) ^ (b & MSB(IEEE754_W))) \
    if (a < 0) ret = -1;\
    else ret = 1;\
  else if (a < 0) ret = -ret;\
  ret;\
})

#define ieee754_lt(a, b, dw) ((ieee754_compare(a, b, dw) < 0)? 1: 0)
#define ieee754_le(a, b, dw) ((ieee754_compare(a, b, dw) <= 0)? 1: 0)
#define ieee754_gt(a, b, dw) ((ieee754_compare(a, b, dw) > 0)? 1: 0)
#define ieee754_ge(a, b, dw) ((ieee754_compare(a, b, dw) >= 0)? 1: 0)
#define ieee754_eq(a, b, dw) ((ieee754_compare(a, b, dw) == 0)? 1: 0)

uint8_t double_is_sub(double val);
uint8_t double_is_nan(double val);
uint8_t double_is_inf(double val);
int8_t double_get_sign(double val);
int32_t double_get_exp(double val);
int64_t double_get_man(double val);

int fprintf_d(FILE *fp, const char *name, double val);
#define printf_d(name, val) fprintf_d(stdout, name, val)

char *base2(double num_d);

uint8_t float_is_sub(float val);
uint8_t float_is_nan(float val);
uint8_t float_is_inf(float val);
int8_t float_get_sign(float val);
int32_t float_get_exp(float val);
int32_t float_get_man(float val);

int fprintf_f(FILE *fp, const char *name, float val);
#define printf_f(name, val) fprintf_f(stdout, name, val)

#endif
