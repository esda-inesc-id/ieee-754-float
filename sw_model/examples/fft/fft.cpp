#include <stdio.h>
#include <stdlib.h>
#include <fstream>

#include "ieee754.h"
#include "common.h"

using namespace std;

int reversed(int ind) {

  ind = ind << 17; // reverse 15 bits
  ind = ((ind >> 1) & 0x55555555u) | ((ind & 0x55555555u) << 1);
  ind = ((ind >> 2) & 0x33333333u) | ((ind & 0x33333333u) << 2);
  ind = ((ind >> 4) & 0x0f0f0f0fu) | ((ind & 0x0f0f0f0fu) << 4);
  ind = ((ind >> 8) & 0x00ff00ffu) | ((ind & 0x00ff00ffu) << 8);
  ind = ((ind >> 16) & 0xffffu) | ((ind & 0xffffu) << 16);

  return ind;
}

void fft_kernel(double *x_d, double *w_d, double *X_d, float *w_f, float *X_f, Ieee754 *w_ieee754, Ieee754 *X_ieee754, int n) {
  int i_max = 0;
  while ((1 << i_max) < n) i_max++;
  int iter, blocks, butterflys;
  int b_max, bf_max;
  int index, index_2, index_ROM;
  double re_1_d, im_1_d, re_2_d, im_2_d, mult_1_d, mult_2_d;
  float re_1_f, im_1_f, re_2_f, im_2_f, mult_1_f, mult_2_f;
  Ieee754 re_1_ieee754, im_1_ieee754, re_2_ieee754, im_2_ieee754, mult_1_ieee754, mult_2_ieee754;

  bf_max = 1;
  b_max = n>>1;

  for (iter = 0; iter < i_max; iter++) {
    for (blocks = 0, index = 0; blocks < b_max; blocks++) {
      for (butterflys = 0, index_ROM = 0; butterflys < bf_max; butterflys++, index++) {
		index_2 = index + (blocks << iter);

		if (iter == 0) {
		  re_1_d = x_d[2*reversed(index_2)];
		  im_1_d = x_d[2*reversed(index_2)+1];

		  re_1_f = (float)x_d[2*reversed(index_2)];
		  im_1_f = (float)x_d[2*reversed(index_2)+1];

		  re_1_ieee754 = (Ieee754)x_d[2*reversed(index_2)];
		  im_1_ieee754 = (Ieee754)x_d[2*reversed(index_2)+1];

		  re_2_d = x_d[2*reversed(index_2+bf_max)];
		  im_2_d = x_d[2*reversed(index_2+bf_max)+1];

		  re_2_f = (float)x_d[2*reversed(index_2+bf_max)];
		  im_2_f = (float)x_d[2*reversed(index_2+bf_max)+1];

		  re_2_ieee754 = (Ieee754)x_d[2*reversed(index_2+bf_max)];
		  im_2_ieee754 = (Ieee754)x_d[2*reversed(index_2+bf_max)+1];
		} else {
		  re_1_d = X_d[2*index_2];
		  im_1_d = X_d[2*index_2+1];

		  re_1_f = X_f[2*index_2];
		  im_1_f = X_f[2*index_2+1];

		  re_1_ieee754 = X_ieee754[2*index_2];
		  im_1_ieee754 = X_ieee754[2*index_2+1];

		  re_2_d = X_d[2*(index_2+bf_max)];
		  im_2_d = X_d[2*(index_2+bf_max)+1];

		  re_2_f = X_f[2*(index_2+bf_max)];
		  im_2_f = X_f[2*(index_2+bf_max)+1];

		  re_2_ieee754 = X_ieee754[2*(index_2+bf_max)];
		  im_2_ieee754 = X_ieee754[2*(index_2+bf_max)+1];
		}

		mult_1_d = re_2_d * w_d[2*index_ROM];
		mult_2_d = im_2_d * w_d[2*index_ROM+1];

		mult_1_f = re_2_f * w_f[2*index_ROM];
		mult_2_f = im_2_f * w_f[2*index_ROM+1];

		mult_1_ieee754 = re_2_ieee754 * w_ieee754[2*index_ROM];
		mult_2_ieee754 = im_2_ieee754 * w_ieee754[2*index_ROM+1];

		// Real part
		X_d[2*index_2] = mult_1_d - mult_2_d + re_1_d;
		X_f[2*index_2] = mult_1_f - mult_2_f + re_1_f;
		X_ieee754[2*index_2] = mult_1_ieee754 - mult_2_ieee754 + re_1_ieee754;

		X_d[2*(index_2+bf_max)] = re_1_d - (mult_1_d - mult_2_d);
		X_f[2*(index_2+bf_max)] = re_1_f - (mult_1_f - mult_2_f);
		X_ieee754[2*(index_2+bf_max)] = re_1_ieee754 - (mult_1_ieee754 - mult_2_ieee754);

		mult_1_d = im_2_d * w_d[2*index_ROM];
		mult_2_d = re_2_d * w_d[2*index_ROM+1];

		mult_1_f = im_2_f * w_f[2*index_ROM];
		mult_2_f = re_2_f * w_f[2*index_ROM+1];

		mult_1_ieee754 = im_2_ieee754 * w_ieee754[2*index_ROM];
		mult_2_ieee754 = re_2_ieee754 * w_ieee754[2*index_ROM+1];

		// Imaginary part
		X_d[2*index_2+1] = mult_1_d + mult_2_d + im_1_d;
		X_f[2*index_2+1] = mult_1_f + mult_2_f + im_1_f;
		X_ieee754[2*index_2+1] = mult_1_ieee754 + mult_2_ieee754 + im_1_ieee754;

		X_d[2*(index_2+bf_max)+1] = im_1_d - (mult_1_d + mult_2_d);
		X_f[2*(index_2+bf_max)+1] = im_1_f - (mult_1_f + mult_2_f);
		X_ieee754[2*(index_2+bf_max)+1] = im_1_ieee754 - (mult_1_ieee754 + mult_2_ieee754);

		index_ROM = index_ROM + b_max;
      }
    }

    bf_max = bf_max<<1;
    b_max = b_max>>1;
  }

  return;
}

void fft(char *inputDir, char *outputDir, FILE *fp_d, FILE *fp_f, FILE *fp_ieee754) {

  // Load x data
  sprintf(buf, "%s/fft/x.txt", inputDir);
  ifstream x_file (buf);
  int n = 0;
  if(x_file.is_open()) x_file >> n;
  double *x_d = (double *)malloc(sizeof(double)*2*n);
  int i = 0;
  while(i < 2*n) x_file >> x_d[i++];
  x_file.close();

  // Load w data
  sprintf(buf, "%s/fft/w.txt", inputDir);
  ifstream w_file (buf);
  int nw = 0;
  if(w_file.is_open()) w_file >> nw;
  double *w_d = (double *)malloc(sizeof(double)*2*nw);
  float *w_f = (float *)malloc(sizeof(float)*2*nw);
  Ieee754 *w_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*2*nw);
  i = 0;
  while(i < 2*nw) {
    w_file >> w_d[i];
    w_f[i] = (float)w_d[i];
    w_ieee754[i] = (Ieee754)w_d[i];
    i++;
  }
  w_file.close();

  double *X_d = (double *)malloc(sizeof(double)*2*n);
  float *X_f = (float *)malloc(sizeof(float)*2*n);
  Ieee754 *X_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*2*n);

  fft_kernel(x_d, w_d, X_d, w_f, X_f, w_ieee754, X_ieee754, n);

  // Store X data
  sprintf(buf, "%s/X.txt", outputDir);
  ofstream X_file (buf);
  for(int j = 0; j < 2*n; j++) {
    X_file << X_d[j] << std::endl;
    fprintf(fp_d, "%.16E\n", X_d[j]);
    fprintf(fp_f, "%.16E\n", X_f[j]);
    fprintf(fp_ieee754, "%.16e\n", (double)X_ieee754[j]);
  }
  X_file.close();

  free(x_d);
  free(w_d);
  free(X_d);

  free(w_f);
  free(X_f);

  free(w_ieee754);
  free(X_ieee754);

  return;
}
