#include <stdio.h>
#include <stdlib.h>

#include "ieee754lib.h"

void mac_test(void) {
  double vec_a_d[10] = {2, 4, 6, -1, -2, -5, 2, -3, 11, 17};
  double vec_b_d[10] = {3, 5, 7, 3, -4, 3, -7, -2, 13, 19};
  uint16_t n = 10;

  ieee754 vec_a_ieee754[1024];
  ieee754 vec_b_ieee754[1024];

  uint16_t i;
  for (i = 0; i < n; i++) {
    vec_a_ieee754[i] = doubletoieee754(vec_a_d[i]);
    vec_b_ieee754[i] = doubletoieee754(vec_b_d[i]);
  }

  ieee754 acc_res = ieee754_mac(vec_a_ieee754, vec_b_ieee754, n);
  printf("acc_res = %.16g\n", ieee754todouble(acc_res));

  n = 1024;
  for (i = 0; i < n; i++) {
    vec_a_ieee754[i] = doubletoieee754(1.0);
    vec_b_ieee754[i] = doubletoieee754(1.0);
  }

  acc_res = ieee754_mac(vec_a_ieee754, vec_b_ieee754, n);
  printf("acc_res = %.16g\n", ieee754todouble(acc_res));

  return;
}

int main(int argc, char **argv) {
  union {
    double   d;
    uint64_t i;
  } conv;

  double num_d = 1;
  ieee754 num_ieee754 = IEEE754_BIAS(IEEE754_EXP_W) << IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W);
  ieee754Unpacked num_ieee754_upk = ieee754_unpack(num_ieee754);
  printf("num_d = %.16g\n", num_d);
  printf("num_ieee754 = 0x%016lx\n", num_ieee754);
  printf("num_ieee754_upk.sign = %hhu\n", num_ieee754_upk.sign);
  printf("num_ieee754_upk.exp  = %d\n", num_ieee754_upk.exp);
  printf("num_ieee754_upk.man  = 0x%06lx\n", num_ieee754_upk.man);
  num_ieee754_upk.man <<=3;
  printf("ieee754_pack() = 0x%016lx\n", ieee754_pack(num_ieee754_upk));
  printf("ieee754todouble() = %.16g\n", ieee754todouble(num_ieee754));
  printf("doubletoieee754() = 0x%016lx\n", doubletoieee754(num_d));
  printf("\n");

  num_d = 2;
  num_ieee754 = (IEEE754_BIAS(IEEE754_EXP_W) + 1) << IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W);
  num_ieee754_upk = ieee754_unpack(num_ieee754);
  printf("num_d = %.16g\n", num_d);
  printf("num_ieee754 = 0x%016lx\n", num_ieee754);
  printf("num_ieee754_upk.sign = %hhu\n", num_ieee754_upk.sign);
  printf("num_ieee754_upk.exp  = %d\n", num_ieee754_upk.exp);
  printf("num_ieee754_upk.man  = 0x%06lx\n", num_ieee754_upk.man);
  num_ieee754_upk.man <<=3;
  printf("ieee754_pack() = 0x%016lx\n", ieee754_pack(num_ieee754_upk));
  printf("ieee754todouble() = %.16g\n", ieee754todouble(num_ieee754));
  printf("doubletoieee754() = 0x%016lx\n", doubletoieee754(num_d));
  printf("\n");

  num_d = -1.75;
  num_ieee754 = -1;
  num_ieee754 = (num_ieee754 << (IEEE754_EXP_W + IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W))) | (IEEE754_BIAS(IEEE754_EXP_W) << IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W)) | (3 << (IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W) - 2));
  num_ieee754_upk = ieee754_unpack(num_ieee754);
  printf("num_d = %.16g\n", num_d);
  printf("num_ieee754 = 0x%016lx\n", num_ieee754);
  printf("num_ieee754_upk.sign = %hhu\n", num_ieee754_upk.sign);
  printf("num_ieee754_upk.exp  = %d\n", num_ieee754_upk.exp);
  printf("num_ieee754_upk.man  = 0x%06lx\n", num_ieee754_upk.man);
  num_ieee754_upk.man <<=3;
  printf("ieee754_pack() = 0x%016lx\n", ieee754_pack(num_ieee754_upk));
  printf("ieee754todouble() = %.16g\n", ieee754todouble(num_ieee754));
  printf("doubletoieee754() = 0x%016lx\n", doubletoieee754(num_d));
  printf("\n");

  num_d = 0.625;
  num_ieee754 = ((IEEE754_BIAS(IEEE754_EXP_W)-1) << IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W)) | (2 << (IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W) - 3));
  num_ieee754_upk = ieee754_unpack(num_ieee754);
  printf("num_d = %.16g\n", num_d);
  printf("num_ieee754 = 0x%016lx\n", num_ieee754);
  printf("num_ieee754_upk.sign = %hhu\n", num_ieee754_upk.sign);
  printf("num_ieee754_upk.exp  = %d\n", num_ieee754_upk.exp);
  printf("num_ieee754_upk.man  = 0x%06lx\n", num_ieee754_upk.man);
  num_ieee754_upk.man <<=3;
  printf("ieee754_pack() = 0x%016lx\n", ieee754_pack(num_ieee754_upk));
  printf("ieee754todouble() = %.16g\n", ieee754todouble(num_ieee754));
  printf("doubletoieee754() = 0x%016lx\n", doubletoieee754(num_d));
  printf("\n");

  num_d = 0;
  num_ieee754 = 0;
  num_ieee754_upk = ieee754_unpack(num_ieee754);
  printf("num_d = %.16g\n", num_d);
  printf("num_ieee754 = 0x%016lx\n", num_ieee754);
  printf("num_ieee754_upk.sign = %hhu\n", num_ieee754_upk.sign);
  printf("num_ieee754_upk.exp  = %d\n", num_ieee754_upk.exp);
  printf("num_ieee754_upk.man  = 0x%06lx\n", num_ieee754_upk.man);
  num_ieee754_upk.man <<=3;
  printf("ieee754_pack() = 0x%016lx\n", ieee754_pack(num_ieee754_upk));
  printf("ieee754todouble() = %.16g\n", ieee754todouble(num_ieee754));
  printf("doubletoieee754() = 0x%016lx\n", doubletoieee754(num_d));
  printf("\n");

  num_d = 0.5;
  num_ieee754 = (IEEE754_BIAS(IEEE754_EXP_W) - 1) << IEEE754_F_W(IEEE754_DATA_W, IEEE754_EXP_W);
  num_ieee754_upk = ieee754_unpack(num_ieee754);
  printf("num_d = %.16g\n", num_d);
  printf("num_ieee754 = 0x%016lx\n", num_ieee754);
  printf("num_ieee754_upk.sign = %hhu\n", num_ieee754_upk.sign);
  printf("num_ieee754_upk.exp  = %d\n", num_ieee754_upk.exp);
  printf("num_ieee754_upk.man  = 0x%06lx\n", num_ieee754_upk.man);
  num_ieee754_upk.man <<=3;
  printf("ieee754_pack() = 0x%016lx\n", ieee754_pack(num_ieee754_upk));
  printf("ieee754todouble() = %.16g\n", ieee754todouble(num_ieee754));
  printf("doubletoieee754() = 0x%016lx\n", doubletoieee754(num_d));
  printf("\n");

  conv.i = IEEE754_NAN(IEEE754_DP_DATA_W, IEEE754_DP_EXP_W);
  num_d = conv.d;
  num_ieee754 = IEEE754_NAN(IEEE754_DATA_W, IEEE754_EXP_W);
  num_ieee754_upk = ieee754_unpack(num_ieee754);
  printf("num_d = %.16g\n", num_d);
  printf("num_ieee754 = 0x%016lx\n", num_ieee754);
  printf("num_ieee754_upk.sign = %hhu\n", num_ieee754_upk.sign);
  printf("num_ieee754_upk.exp  = %d\n", num_ieee754_upk.exp);
  printf("num_ieee754_upk.man  = 0x%06lx\n", num_ieee754_upk.man);
  num_ieee754_upk.man <<=3;
  printf("ieee754_pack() = 0x%016lx\n", ieee754_pack(num_ieee754_upk));
  printf("ieee754todouble() = %.16g\n", ieee754todouble(num_ieee754));
  printf("doubletoieee754() = 0x%016lx\n", doubletoieee754(num_d));
  printf("\n");

  double op_a_d = 3;
  double op_b_d = 5;
  ieee754 op_a_ieee754 = doubletoieee754(op_a_d);
  ieee754 op_b_ieee754 = doubletoieee754(op_b_d);
  ieee754 res_ieee754 = ieee754_add(op_a_ieee754, op_b_ieee754);
  printf("%.16g + %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 3;
  op_b_d = 5;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_sub(op_a_ieee754, op_b_ieee754);
  printf("%.16g - %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 1;
  op_b_d = 2;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_sub(op_a_ieee754, op_b_ieee754);
  printf("%.16g - %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 1;
  op_b_d = 2;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_add(op_a_ieee754, op_b_ieee754);
  printf("%.16g + %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 2;
  op_b_d = 4;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_add(op_a_ieee754, op_b_ieee754);
  printf("%.16g + %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 2;
  op_b_d = 3;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_add(op_a_ieee754, op_b_ieee754);
  printf("%.16g + %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 2;
  op_b_d = 7;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_add(op_a_ieee754, op_b_ieee754);
  printf("%.16g + %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 3;
  op_b_d = 5;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_mul(op_a_ieee754, op_b_ieee754);
  printf("%.16g * %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 2;
  op_b_d = -3;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_mul(op_a_ieee754, op_b_ieee754);
  printf("%.16g * %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = -2;
  op_b_d = 3;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_mul(op_a_ieee754, op_b_ieee754);
  printf("%.16g * %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 1.99999999;
  op_b_d = 1.99999999;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_mul(op_a_ieee754, op_b_ieee754);
  printf("%.16g * %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = -5;
  op_b_d = 4;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_div(op_a_ieee754, op_b_ieee754);
  printf("%.16g / %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 4;
  op_b_d = 5;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_div(op_a_ieee754, op_b_ieee754);
  printf("%.16g / %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 2;
  op_b_d = 0;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_div(op_a_ieee754, op_b_ieee754);
  printf("%.16g / %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  op_a_d = 2;
  op_b_d = 3;
  op_a_ieee754 = doubletoieee754(op_a_d);
  op_b_ieee754 = doubletoieee754(op_b_d);
  res_ieee754 = ieee754_div(op_a_ieee754, op_b_ieee754);
  printf("%.16g / %.16g = %.16g\n", op_a_d, op_b_d, ieee754todouble(res_ieee754));

  mac_test();

  return 0;
}
