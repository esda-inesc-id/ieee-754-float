#include <stdio.h>
#include <stdlib.h>
#include <fstream>

#include "ieee754.h"
#include "common.h"

using namespace std;

#define ERR_THRESH 0.001

#define MAX_LOOP 5
#define MAX_DIFF 0.15

#define F(x) 	(A_coeff[k]*(x)*(x)*(x) + B_coeff[k]*(x)*(x) + C_coeff[k]*(x) + D_coeff[k])
#define FD(x) 	(3.0*A_coeff[k]*(x)*(x) + 2.0*B_coeff[k]*(x) + C_coeff[k])

void nr_kernel_d(double *A_coeff, double *B_coeff, double *C_coeff, double *D_coeff, double *x0_in, double *root, int size, double err_thresh) {
  for (int k = 0; k < size; k++) {
    double curr_err = MAX_DIFF * err_thresh;
    double x0 = x0_in[k];
    double x1, fx, fdx;
    for (int i = 0; i < MAX_LOOP; i++) {
      fx  = F(x0);
      fdx = FD(x0);
      if (!fdx) continue;
      x1  = x0 - (fx/fdx);
      if (fabs((x1-x0) / x1) < curr_err) {
        curr_err = fabs((x1-x0) / x1);
        root[k]= x1;
      }
      x0 = x1;
    }
  }

  return;
}

void nr_kernel_f(float *A_coeff, float *B_coeff, float *C_coeff, float *D_coeff, float *x0_in, float *root, int size, float err_thresh) {
  for (int k = 0; k < size; k++) {
    float curr_err = MAX_DIFF * err_thresh;
    float x0 = x0_in[k];
    float x1, fx, fdx;
    for (int i = 0; i < MAX_LOOP; i++) {
      fx  = F(x0);
      fdx = FD(x0);
      if (!fdx) continue;
      x1  = x0 - (fx/fdx);
      if (fabs((x1-x0) / x1) < curr_err) {
        curr_err = fabs((x1-x0) / x1);
        root[k]= x1;
      }
      x0 = x1;
    }
  }

  return;
}

void nr_kernel_ieee754(Ieee754 *A_coeff, Ieee754 *B_coeff, Ieee754 *C_coeff, Ieee754 *D_coeff, Ieee754 *x0_in, Ieee754 *root, int size, Ieee754 err_thresh) {
  for (int k = 0; k < size; k++) {
    Ieee754 curr_err = MAX_DIFF * err_thresh;
    Ieee754 x0 = x0_in[k];
    Ieee754 x1, fx, fdx;
    for (int i = 0; i < MAX_LOOP; i++) {
      fx  = F(x0);
      fdx = FD(x0);
      if (!fdx) continue;
      x1  = x0 - (fx/fdx);
      if (fabs((x1-x0) / x1) < curr_err) {
        curr_err = fabs((x1-x0) / x1);
        root[k]= x1;
      }
      x0 = x1;
    }
  }

  return;
}

void nr(char *inputDir, char *outputDir, FILE *fp_d, FILE *fp_f, FILE *fp_ieee754) {

  // process the files
  sprintf(buf, "%s/newton-raph/coeff_in.txt", inputDir);
  ifstream coeff_in_file (buf);

  int data_size = 0;
  if(coeff_in_file.is_open()) {
    coeff_in_file >> data_size;
    std::cout << "# Data Size = " << data_size << std::endl;
  }

  double* A_coeff_d = (double *)malloc(sizeof(double)*data_size);
  double* B_coeff_d = (double *)malloc(sizeof(double)*data_size);
  double* C_coeff_d = (double *)malloc(sizeof(double)*data_size);
  double* D_coeff_d = (double *)malloc(sizeof(double)*data_size);
  double* x0_d = (double *)malloc(sizeof(double)*data_size);
  double* root_d = (double *)malloc(sizeof(double)*data_size);
  if (!A_coeff_d || !B_coeff_d || !C_coeff_d || !x0_d || !root_d) {
    std::cerr << "Memory allocation fails!!!" << std::endl;
    exit(EXIT_FAILURE);
  }

  float* A_coeff_f = (float *)malloc(sizeof(float)*data_size);
  float* B_coeff_f = (float *)malloc(sizeof(float)*data_size);
  float* C_coeff_f = (float *)malloc(sizeof(float)*data_size);
  float* D_coeff_f = (float *)malloc(sizeof(float)*data_size);
  float* x0_f = (float *)malloc(sizeof(float)*data_size);
  float* root_f = (float *)malloc(sizeof(float)*data_size);
  if (!A_coeff_f || !B_coeff_f || !C_coeff_f || !x0_f || !root_f) {
    std::cerr << "Memory allocation fails!!!" << std::endl;
    exit(EXIT_FAILURE);
  }

  Ieee754* A_coeff_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*data_size);
  Ieee754* B_coeff_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*data_size);
  Ieee754* C_coeff_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*data_size);
  Ieee754* D_coeff_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*data_size);
  Ieee754* x0_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*data_size);
  Ieee754* root_ieee754 = (Ieee754 *)malloc(sizeof(Ieee754)*data_size);
  if (!A_coeff_ieee754 || !B_coeff_ieee754 || !C_coeff_ieee754 || !x0_ieee754 || !root_ieee754) {
    std::cerr << "Memory allocation fails!!!" << std::endl;
    exit(EXIT_FAILURE);
  }

  // add data to the arrays
  double A_tmp, B_tmp, C_tmp, D_tmp, x0_tmp;
  int coeff_index = 0;
  while(coeff_index < data_size) {	
    coeff_in_file >> A_tmp >> B_tmp >> C_tmp >> D_tmp >> x0_tmp;

    root_d    [coeff_index] = 0;
    A_coeff_d [coeff_index] = A_tmp;
    B_coeff_d [coeff_index] = B_tmp;
    C_coeff_d [coeff_index] = C_tmp;
    D_coeff_d [coeff_index] = D_tmp;
    x0_d      [coeff_index] = x0_tmp;

    root_f    [coeff_index] = (float)0;
    A_coeff_f [coeff_index] = (float)A_tmp;
    B_coeff_f [coeff_index] = (float)B_tmp;
    C_coeff_f [coeff_index] = (float)C_tmp;
    D_coeff_f [coeff_index] = (float)D_tmp;
    x0_f      [coeff_index] = (float)x0_tmp;

    root_ieee754    [coeff_index] = (Ieee754)0;
    A_coeff_ieee754 [coeff_index] = (Ieee754)A_tmp;
    B_coeff_ieee754 [coeff_index] = (Ieee754)B_tmp;
    C_coeff_ieee754 [coeff_index] = (Ieee754)C_tmp;
    D_coeff_ieee754 [coeff_index] = (Ieee754)D_tmp;
    x0_ieee754      [coeff_index] = (Ieee754)x0_tmp;

    coeff_index++;
  }
  coeff_in_file.close();

  nr_kernel_d(A_coeff_d, B_coeff_d, C_coeff_d, D_coeff_d, x0_d, root_d, data_size, ERR_THRESH);
  nr_kernel_f(A_coeff_f, B_coeff_f, C_coeff_f, D_coeff_f, x0_f, root_f, data_size, ERR_THRESH);
  nr_kernel_ieee754(A_coeff_ieee754, B_coeff_ieee754, C_coeff_ieee754, D_coeff_ieee754, x0_ieee754, root_ieee754, data_size, (Ieee754)ERR_THRESH);

  sprintf(buf, "%s/newton_raph.txt", outputDir);
  ofstream root_out_file (buf);
  for(int i = 0; i < data_size; i++) {
    root_out_file << root_d[i] << std::endl;
    fprintf(fp_d, "%.16E\n", root_d[i]);
    fprintf(fp_f, "%.16E\n", root_f[i]);
    fprintf(fp_ieee754, "%.16e\n", root_ieee754[i]);
  }

  root_out_file.close();

  return;
}
