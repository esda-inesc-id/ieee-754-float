// Command-line driver of the C model, reading vectors from stdin.
//
// model_run tf <add|sub|mul|div> <data_w> <exp_w>   compares with TestFloat vectors
// model_run mix <data_w> <exp_w>                    "funct a b ..." lines, one result per line
// model_run mac <data_w> <exp_w> <lguard> <rguard>  product streams, one result per stream

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ieee754_model.h"

typedef uint64_t (*binary_op)(uint64_t, uint64_t, int, int);

static int is_nan(uint64_t bits, int data_w, int exp_w) {
  int f_w = data_w - exp_w - 1;
  uint64_t exp_ones = ((uint64_t)1 << exp_w) - 1;
  return ((bits >> f_w) & exp_ones) == exp_ones && (bits & (((uint64_t)1 << f_w) - 1)) != 0;
}

static binary_op find_op(const char *name) {
  if (!strcmp(name, "add")) return ieee754_add;
  if (!strcmp(name, "sub")) return ieee754_sub;
  if (!strcmp(name, "mul")) return ieee754_mul;
  if (!strcmp(name, "div")) return ieee754_div;
  return NULL;
}

static int run_testfloat(const char *name, int data_w, int exp_w) {
  binary_op op = find_op(name);
  if (!op) return 2;

  uint64_t a, b, expected;
  unsigned flags;
  uint64_t vectors = 0, mismatches = 0;
  while (scanf("%" SCNx64 " %" SCNx64 " %" SCNx64 " %x", &a, &b, &expected, &flags) == 4) {
    uint64_t res = op(a, b, data_w, exp_w);
    vectors++;
    if (res != expected && !(is_nan(res, data_w, exp_w) && is_nan(expected, data_w, exp_w))) {
      if (mismatches < 10) {
        fprintf(stderr, "%s %" PRIx64 " %" PRIx64 ": expected %" PRIx64 ", model %" PRIx64 "\n",
                name, a, b, expected, res);
      }
      mismatches++;
    }
  }
  printf("f%d_%s vectors=%" PRIu64 " mismatches=%" PRIu64 "\n", data_w, name, vectors, mismatches);
  return mismatches != 0 || vectors == 0;
}

static int run_mix(int data_w, int exp_w) {
  static const binary_op ops[4] = {ieee754_add, ieee754_sub, ieee754_mul, ieee754_div};
  char line[256];
  while (fgets(line, sizeof line, stdin)) {
    unsigned funct;
    uint64_t a, b;
    if (sscanf(line, "%u %" SCNx64 " %" SCNx64, &funct, &a, &b) != 3 || funct > 3) return 2;
    printf("%0*" PRIx64 "\n", data_w / 4, ops[funct](a, b, data_w, exp_w));
  }
  return 0;
}

static int run_mac(int data_w, int exp_w, int lguard_w, int rguard_w) {
  ieee754_mac *mac = ieee754_mac_new(data_w, exp_w, lguard_w, rguard_w);
  if (!mac) return 2;
  unsigned n;
  while (scanf("%u", &n) == 1) {
    for (unsigned i = 0; i < n; i++) {
      uint64_t a, b;
      if (scanf("%" SCNx64 " %" SCNx64, &a, &b) != 2) return 2;
      ieee754_mac_push(mac, a, b);
    }
    printf("%0*" PRIx64 "\n", data_w / 4, ieee754_mac_result(mac));
  }
  ieee754_mac_free(mac);
  return 0;
}

int main(int argc, char **argv) {
  if (argc == 5 && !strcmp(argv[1], "tf")) {
    return run_testfloat(argv[2], atoi(argv[3]), atoi(argv[4]));
  }
  if (argc == 4 && !strcmp(argv[1], "mix")) return run_mix(atoi(argv[2]), atoi(argv[3]));
  if (argc == 6 && !strcmp(argv[1], "mac")) {
    return run_mac(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
  }
  fprintf(stderr, "usage: see the header of model_run.c\n");
  return 2;
}
