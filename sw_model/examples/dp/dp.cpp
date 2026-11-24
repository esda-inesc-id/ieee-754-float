#include <stdio.h>
#include <stdlib.h>
#include <float.h>

#include "ieee754.h"
#include "common.h"

void mac(double *a_d, double *b_d, double *acc_d,
              float *a_f, float *b_f, float *acc_f,
              Ieee754 *a_ieee754, Ieee754 *b_ieee754, Ieee754 *acc_ieee754,
              unsigned int n) {
  for (unsigned int i = 0; i < n; i++) {
    *acc_d += a_d[i] * b_d[i];
    *acc_f += a_f[i] * b_f[i];
    *acc_ieee754 += a_ieee754[i] * b_ieee754[i];
  }
  return;
}

void dp_kernel(double *data, unsigned int n, double *weights, unsigned int m, FILE *fp_d, FILE *fp_f, FILE *fp_ieee754) {
  double *a_d = (double *)calloc(m, sizeof(double));
  double *b_d = weights;
  float *a_f = (float *)calloc(m, sizeof(float));
  float *b_f = (float *)calloc(m, sizeof(float));
  Ieee754 *a_ieee754 = (Ieee754 *)calloc(m, sizeof(Ieee754));
  Ieee754 *b_ieee754 = (Ieee754 *)calloc(m, sizeof(Ieee754));

  memcpy(b_f, b_d, m*sizeof(double));
  memcpy(b_ieee754, b_d, m*sizeof(double));

  double max_acc = 0.0;
  double min_acc = DBL_MAX;

  printf("\nMAC tests\n\n");
  for (unsigned int i = 0; i <= n-m; i++) {
    memcpy(a_d, &data[i], m*sizeof(double));
    memcpy(a_f, a_d, m*sizeof(double));
    memcpy(a_ieee754, a_d, m*sizeof(double));

    double c_d = 0.0;
    float c_f = 0.0;
    Ieee754 c_ieee754 = 0.0;
    mac(a_d, b_d, &c_d,
        a_f, b_f, &c_f,
        a_ieee754, b_ieee754, &c_ieee754,
        m);

    if (abs(c_d) > max_acc) max_acc = abs(c_d);
    if (abs(c_d) < min_acc) min_acc = abs(c_d);

    fprintf(fp_d, "%.16E\n", c_d);
    fprintf(fp_f, "%.16E\n", c_f);
    fprintf(fp_ieee754, "%.16e\n", (double)c_ieee754);
  }

  printf("max_acc = %.16E\n", max_acc);
  printf("min_acc = %.16E\n", min_acc);

  free(a_d);
  free(a_f);
  free(b_f);
  free(a_ieee754);
  free(b_ieee754);

  return;
}

void dp(char *inputDir, char *outputDir, FILE *fp_d, FILE *fp_f, FILE *fp_ieee754) {

  // Load input data
  double *data;
  sprintf(buf, "%s/dp/data.in", inputDir);
  unsigned int n = read_input(buf, &data);

  // Load weights
  double *weights;
  sprintf(buf, "%s/dp/weights.in", inputDir);
  unsigned int m = read_input(buf, &weights);

  dp_kernel(data, n, weights, m, fp_d, fp_f, fp_ieee754);

  double max = 0.0;
  double min = DBL_MAX;
  for (unsigned int j = 0; j < n; j++) {
    if (abs(data[j]) > max) max = abs(data[j]);
    if (abs(data[j]) < min) min = abs(data[j]);
  }

  for (unsigned int j = 0; j < m; j++) {
    if (abs(weights[j]) > max) max = abs(weights[j]);
    if (abs(weights[j]) < min) min = abs(weights[j]);
  }
  printf("max = %.16E\n", max);
  printf("min = %.16E\n", min);

  free(data);
  free(weights);

  return;
}
