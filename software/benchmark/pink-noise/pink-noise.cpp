#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "common.h"
#include "ieee754.h"

#define SIZE 6
#define Fs 48e3
#define TEST_DURATION (Fs*.1) //given in samples for 5 seconds @48kHz

double pink_d(double *xp,  double *yp) {
  double acc = 0;
  double bcc = 0;

  int i;

  double xc[SIZE] =  {
#include "NUM.txt"
  };

  double yc[SIZE] =  {
#include "DEN.txt"
  };

  for (i=0; i<SIZE; i++) {
    acc += xc[i] * xp[-i];
    bcc += yc[i] * yp[-i];
  }

  return (acc-bcc) ;
}

float pink_f(float *xp,  float *yp) {
  float acc = 0;
  float bcc = 0;

  int i;

  double xc[SIZE] =  {
#include "NUM.txt"
  };

  double yc[SIZE] =  {
#include "DEN.txt"
  };

  for (i=0; i<SIZE; i++) {
    acc += (float)xc[i] * xp[-i];
    bcc += (float)yc[i] * yp[-i];
  }

  return (acc-bcc) ;
}

Ieee754 pink_ieee754(Ieee754 *xp, Ieee754 *yp) {
  Ieee754 acc = 0;
  Ieee754 bcc = 0;

  int i;

  double xc[SIZE] =  {
#include "NUM.txt"
  };

  double yc[SIZE] =  {
#include "DEN.txt"
  };

  for (i=0; i<SIZE; i++) {
    acc += (Ieee754)xc[i] * xp[-i];
    bcc += (Ieee754)yc[i] * yp[-i];
  }

  return (acc-bcc) ;
}


//  Example to generate a pink noise vector y

void pink_noise(char *inputDir, char *outputDir, FILE *fp_d, FILE *fp_f, FILE *fp_ieee754){
  int i;

  double *x_d = (double *) malloc(TEST_DURATION*sizeof(double));
  double *y_d = (double *) malloc(TEST_DURATION*sizeof(double));

  float *x_f = (float *) malloc(TEST_DURATION*sizeof(float));
  float *y_f = (float *) malloc(TEST_DURATION*sizeof(float));

  Ieee754 *x_ieee754 = (Ieee754 *) malloc(TEST_DURATION*sizeof(Ieee754));
  Ieee754 *y_ieee754 = (Ieee754 *) malloc(TEST_DURATION*sizeof(Ieee754));

  sprintf(buf, "%s/pink_noise_in.txt", outputDir);
  FILE *fp = fopen(buf, "w");
  // generate white noise input vector in format 1Q32
  // init response vector
  for (i=0; i<TEST_DURATION; i++) {
    if(i< SIZE)
      x_d[i] = 0;
    else
      x_d[i] = 2*( (double) rand() - RAND_MAX/2)/RAND_MAX;
    x_f[i] = (float)x_d[i];
    x_ieee754[i] = (Ieee754)x_d[i];
    y_d[i] = 0;
    y_f[i] = 0;
    y_ieee754[i] = 0;
  }
  fclose(fp);

  // compute filter response
  for (i=6; i<TEST_DURATION; i++) {
    y_d[i] = pink_d( x_d+i-1, y_d+i-1);
    y_f[i] = pink_f( x_f+i-1, y_f+i-1);
    y_ieee754[i] = pink_ieee754( x_ieee754+i-1, y_ieee754+i-1);
  }

  // print response
  sprintf(buf, "%s/pink_noise.txt", outputDir);
  fp = fopen(buf, "w");
  for (i=0; i<TEST_DURATION; i++) {
    fprintf(fp, "%20F\n", y_d[i]);
    //printf("%d\n", x[i]);
    fprintf(fp_d, "%.16E\n", y_d[i]);
    fprintf(fp_f, "%.16E\n", y_f[i]);
    fprintf(fp_ieee754, "%.16e\n", y_ieee754[i]);
  }
  fclose(fp);

  free(x_d);
  free(y_d);

  free(x_f);
  free(y_f);

  free(x_ieee754);
  free(y_ieee754);

  return;

}
