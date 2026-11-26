// Writes every a*b + c of a small format, with the model's result, as TestFloat mulAdd
// vectors ("a b c result flags", hex) for the RTL testbench. The model's ffma matches
// MPFR on these formats exhaustively (make fma-formats).
// usage: fma_vectors <data_w> <exp_w> <rounding mode 0..4>
#include <stdio.h>
#include <stdlib.h>

#include "ieee754_model.h"

int main(int argc, char **argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: fma_vectors <data_w> <exp_w> <mode>\n");
    return 1;
  }
  int dw = atoi(argv[1]), ew = atoi(argv[2]);
  if (dw < 4 || dw > 16) {
    fprintf(stderr, "fma_vectors: data_w 4..16\n");
    return 1;
  }
  ieee754_set_rounding(atoi(argv[3]));
  int digits = (dw + 3) / 4;
  unsigned n = 1u << dw;
  for (unsigned a = 0; a < n; a++)
    for (unsigned b = 0; b < n; b++)
      for (unsigned c = 0; c < n; c++)
        printf("%0*x %0*x %0*x %0*x 00\n", digits, a, digits, b, digits, c, digits,
               (unsigned)ieee754_fma_w(a, b, c, dw, ew));
  return 0;
}
