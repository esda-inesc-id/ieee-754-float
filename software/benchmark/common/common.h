#ifndef COMMON_H
#define COMMON_H

#include <stdint.h>

extern char buf[1024];

int32_t rand32(void);
int64_t rand64(void);
int32_t randn(int n);
float randCommon(void);
float randFloatMAC(void);
float randFloat(void);
double randDouble(void);
double* generate_random_input(unsigned int n);

unsigned int read_input(char *inputFile, double **data);
unsigned int read_input(char *inputFile, float **data);
void write_output(char *outputFile, double *data, int n);
void write_output(char *outputFile, float *data, int n);

inline void *memcpy(float *f_ptr, const double *d_ptr, size_t n) {
  n /= sizeof(double);
  while (n--) f_ptr[n] = (float)d_ptr[n];
  return (void *)f_ptr;
}

inline void *memcpy(double *d_ptr, const float *f_ptr, size_t n) {
  n /= sizeof(float);
  while (n--) d_ptr[n] = (double)f_ptr[n];
  return (void *)d_ptr;
}

#endif
