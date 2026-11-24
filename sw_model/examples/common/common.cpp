#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ieee754.h"
#include "common.h"

char buf[1024];

int32_t rand32(void) {
  int32_t num = rand();
  num |= (int32_t)rand() << 15;
  num |= (int32_t)rand() << 30;
  return num;
}

int64_t rand64(void) {
  int64_t num = (int64_t)rand32() & 0x00000000ffffffff;
  num |= (int64_t)rand32() << 32;
  return num;
}

int32_t randn(int n) {
  int32_t num = rand32();
  num &= (1 << n) - 1;
  return num;
}

float randCommon(void) {
  union {
    float   f;
    int32_t i;
  } conv;
  int32_t exp_mask = (1 << IEEE754_SP_EXP_W) - 1;
  int32_t r = randn(IEEE754_SP_EXP_W*2) / (exp_mask + 1);
  int32_t exp = (r % (exp_mask - 1)) - (IEEE754_SP_BIAS - 1);
  int32_t man = rand32();

  int32_t sign = 0;
  if (man < 0) {
    man = -man;
    sign = 1;
  }

  int32_t width = 19;
  man = (man >> (IEEE754_SP_DATA_W - width)) & ((1 << width) - 1);
  exp += IEEE754_SP_BIAS;

  conv.i = man << (IEEE754_SP_F_W - width);
  conv.i |= exp << IEEE754_SP_F_W;
  conv.i |= sign << (IEEE754_SP_DATA_W - 1);

  return conv.f;
}

float randFloatMAC(void) {
  union {
    float   f;
    int32_t i;
  } conv;
  int32_t exp_mask = (1 << IEEE754_SP_EXP_W) - 1;
  int32_t r = randn(IEEE754_SP_EXP_W*2) / (exp_mask + 1);
  int32_t exp = (r % (exp_mask - 1)) - (IEEE754_SP_BIAS - 1);
  exp = exp/2 - exp/64;
  int32_t man = rand32();

  int32_t sign = 0;
  if (man < 0) {
    man = -man;
    sign = 1;
  }

  int32_t width = IEEE754_SP_F_W;
  man = (man >> (IEEE754_SP_DATA_W - width)) & ((1 << width) - 1);
  exp += IEEE754_SP_BIAS;

  conv.i = man;
  conv.i |= exp << IEEE754_SP_F_W;
  conv.i |= sign << (IEEE754_SP_DATA_W - 1);

  return conv.f;
}

float randFloat(void) {
  union {
    float   f;
    int32_t i;
  } conv;
  int32_t exp_mask = (1 << IEEE754_SP_EXP_W) - 1;
  int32_t r = randn(IEEE754_SP_EXP_W*2) / (exp_mask + 1);
  int32_t exp = (r % (exp_mask - 1)) - (IEEE754_SP_BIAS - 1);
  int32_t man = rand32();

  int32_t sign = 0;
  if (man < 0) {
    man = -man;
    sign = 1;
  }

  int32_t width = IEEE754_SP_F_W;
  man = (man >> (IEEE754_SP_DATA_W - width)) & ((1 << width) - 1);
  exp += IEEE754_SP_BIAS;

  conv.i = man;
  conv.i |= exp << IEEE754_SP_F_W;
  conv.i |= sign << (IEEE754_SP_DATA_W - 1);

  return conv.f;
}

double randDouble(void) {
  union {
    double  d;
    int64_t i;
  } conv;
  int64_t exp_mask = (1 << IEEE754_DP_EXP_W) - 1;
  int64_t r = randn(IEEE754_DP_EXP_W*2) / (exp_mask + 1);
  int64_t exp = (r % (exp_mask - 1)) - (IEEE754_DP_BIAS - 1);
  int64_t man = rand64();

  int64_t sign = 0;
  if (man < 0) {
    man = -man;
    sign = 1;
  }

  int64_t width = IEEE754_DP_F_W;
  man = (man >> (IEEE754_DP_DATA_W - width)) & (((int64_t)1 << width) - 1);
  exp += IEEE754_DP_BIAS;

  conv.i = man;
  conv.i |= exp << IEEE754_DP_F_W;
  conv.i |= sign << (IEEE754_DP_DATA_W - 1);

  return conv.d;
}

double* generate_random_input(unsigned int n) {

  // seed the generator
  //srand(time(0));

  double *vec = (double *) malloc(sizeof(double)*n);

  unsigned int i;
  for (i = 0; i < n; i++) {
    //vec[i] = randDouble();
    //vec[i] = randFloat();
    vec[i] = randFloatMAC();
  }

  return vec;
}

unsigned int read_input(char *inputFile, double **data) {

  FILE *fp = fopen(inputFile, "r");
  if (!fp) {
    fprintf(stderr, "unable to open file '%s'\n", inputFile);
    exit(1);
  }

  int n;
  int ret = fread(&n, sizeof(int), 1, fp);

  float *data_f = (float *) malloc(sizeof(float)*n);
  if (!data_f) {
    fprintf(stderr, "memory allocation failed\n");
    exit(1);
  }
  ret = fread(data_f, sizeof(float), n, fp);

  *data = (double *) malloc(sizeof(double)*n);
  if (!*data) {
    fprintf(stderr, "memory allocation failed\n");
    exit(1);
  }
  memcpy(*data, data_f, sizeof(float)*n);

  free(data_f);

  fclose(fp);

  return (unsigned int)ret;
}

unsigned int read_input(char *inputFile, float **data) {

  FILE *fp = fopen(inputFile, "r");
  if (!fp) {
    fprintf(stderr, "unable to open file '%s'\n", inputFile);
    exit(1);
  }

  int n;
  int ret = fread(&n, sizeof(int), 1, fp);

  *data = (float *) malloc(sizeof(float)*n);
  if (!*data) {
    fprintf(stderr, "memory allocation failed\n");
    exit(1);
  }
  ret = fread(*data, sizeof(float), n, fp);

  fclose(fp);

  return (unsigned int)ret;
}

void write_output(char *outputFile, double *data, int n) {

  FILE *fp = fopen(outputFile, "w");
  if (!fp) {
    fprintf(stderr, "unable to open file '%s'\n", outputFile);
    exit(1);
  }

  fwrite(data, sizeof(double), n, fp);

  fclose(fp);

  return;
}

void write_output(char *outputFile, float *data, int n) {

  FILE *fp = fopen(outputFile, "w");
  if (!fp) {
    fprintf(stderr, "unable to open file '%s'\n", outputFile);
    exit(1);
  }

  fwrite(data, sizeof(float), n, fp);

  fclose(fp);

  return;
}
