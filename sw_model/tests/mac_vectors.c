// Writes random fmac product streams of one format for the RTL stream testbench
// (fmac/hw/sim/src/fmac_streams_tb.v) and the model's result of each, to check the RTL
// bit for bit. Half of the streams cancel: each product is followed later by its negation.
// usage: mac_vectors <data_w> <exp_w> <rounding mode 0..4> <streams> <streams.tv> <expected>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ieee754_model.h"

static uint64_t rng = 0x2545f4914f6cdd1dull;
static uint64_t next(void) {
  rng ^= rng << 13;
  rng ^= rng >> 7;
  rng ^= rng << 17;
  return rng;
}

int main(int argc, char **argv) {
  if (argc != 7) {
    fprintf(stderr, "usage: mac_vectors <data_w> <exp_w> <mode> <streams> <streams.tv> <expected>\n");
    return 1;
  }
  int dw = atoi(argv[1]), ew = atoi(argv[2]), count = atoi(argv[4]);
  if (dw < 4 || dw > 64) {
    fprintf(stderr, "mac_vectors: data_w 4..64\n");
    return 1;
  }
  ieee754_mac *mac = ieee754_mac_new(dw, ew, 0, 0);
  FILE *tv = fopen(argv[5], "w"), *exp = fopen(argv[6], "w");
  if (!mac || !tv || !exp) {
    fprintf(stderr, "mac_vectors: cannot start\n");
    return 1;
  }
  ieee754_set_rounding(atoi(argv[3]));
  int digits = (dw + 3) / 4;
  uint64_t mask = dw == 64 ? ~0ull : (1ull << dw) - 1, sign = 1ull << (dw - 1);
  uint64_t a[64], b[64];
  for (int s = 0; s < count; s++) {
    int n = 1 + (int)(next() % 32);
    if (s % 2) {
      // cancellation: a product and, later, its negation
      int half = (n + 1) / 2;
      for (int i = 0; i < half; i++) a[i] = next() & mask, b[i] = next() & mask;
      for (int i = 0; i < half; i++) a[half + i] = a[i] ^ sign, b[half + i] = b[i];
      n = 2 * half;
    } else {
      for (int i = 0; i < n; i++) a[i] = next() & mask, b[i] = next() & mask;
    }
    fprintf(tv, "%d\n", n);
    for (int i = 0; i < n; i++) {
      fprintf(tv, "%0*llx %0*llx\n", digits, (unsigned long long)a[i], digits, (unsigned long long)b[i]);
      ieee754_mac_push(mac, a[i], b[i]);
    }
    fprintf(exp, "%0*llx\n", digits, (unsigned long long)ieee754_mac_result(mac));
  }
  ieee754_mac_free(mac);
  fclose(tv);
  fclose(exp);
  return 0;
}
