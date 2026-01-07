#include <stdio.h>
#include <stdlib.h>

#include "benchmark.h"
#include "common.h"

extern char buf[1024];

void run_benchmark(char *inputDir, char *outputDir) {
  FILE *fp_d, *fp_f, *fp_ieee754;

  //
  // Dot Product
  //
  sprintf(buf, "%s/dp-double.out", outputDir);
  fp_d = fopen(buf, "w");
  if (!fp_d) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    exit(1);
  }

  sprintf(buf, "%s/dp-float.out", outputDir);
  fp_f = fopen(buf, "w");
  if (!fp_f) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    exit(1);
  }

  sprintf(buf, "%s/dp-ieee754.out", outputDir);
  fp_ieee754 = fopen(buf, "w");
  if (!fp_ieee754) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    fclose(fp_f);
    exit(1);
  }

  printf("\nDot Product\n\n");
  dp(inputDir, outputDir, fp_d, fp_f, fp_ieee754);

  fclose(fp_d);
  fclose(fp_f);
  fclose(fp_ieee754);

  //
  // Newton-Raphson
  //
  sprintf(buf, "%s/nr-double.out", outputDir);
  fp_d = fopen(buf, "w");
  if (!fp_d) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    exit(1);
  }

  sprintf(buf, "%s/nr-float.out", outputDir);
  fp_f = fopen(buf, "w");
  if (!fp_f) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    exit(1);
  }

  sprintf(buf, "%s/nr-ieee754.out", outputDir);
  fp_ieee754 = fopen(buf, "w");
  if (!fp_ieee754) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    fclose(fp_f);
    exit(1);
  }

  printf("\nNewton-Raphson\n\n");
  nr(inputDir, outputDir, fp_d, fp_f, fp_ieee754);

  fclose(fp_d);
  fclose(fp_f);
  fclose(fp_ieee754);

  //
  // Fast Fourier Transform
  //
  sprintf(buf, "%s/fft-double.out", outputDir);
  fp_d = fopen(buf, "w");
  if (!fp_d) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    exit(1);
  }

  sprintf(buf, "%s/fft-float.out", outputDir);
  fp_f = fopen(buf, "w");
  if (!fp_f) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    exit(1);
  }

  sprintf(buf, "%s/fft-ieee754.out", outputDir);
  fp_ieee754 = fopen(buf, "w");
  if (!fp_ieee754) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    fclose(fp_f);
    exit(1);
  }

  printf("\nFast Fourier Transform\n\n");
  fft(inputDir, outputDir, fp_d, fp_f, fp_ieee754);

  fclose(fp_d);
  fclose(fp_f);
  fclose(fp_ieee754);

  //
  // k-Means Clustering
  //
  /*sprintf(buf, "%s/kmeans-double.out", outputDir);
  fp_d = fopen(buf, "w");
  if (!fp_d) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    exit(1);
  }

  sprintf(buf, "%s/kmeans-float.out", outputDir);
  fp_f = fopen(buf, "w");
  if (!fp_f) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    exit(1);
  }

  sprintf(buf, "%s/kmeans-ieee754.out", outputDir);
  fp_ieee754 = fopen(buf, "w");
  if (!fp_ieee754) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    fclose(fp_f);
    exit(1);
  }

  printf("\nk-Means Clustering\n\n");
  kmeans(inputDir, outputDir, fp_d, fp_f, fp_ieee754);

  fclose(fp_d);
  fclose(fp_f);
  fclose(fp_ieee754);*/

  //
  // Black-Scholes
  //
  sprintf(buf, "%s/blackscholes-double.out", outputDir);
  fp_d = fopen(buf, "w");
  if (!fp_d) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    exit(1);
  }

  sprintf(buf, "%s/blackscholes-float.out", outputDir);
  fp_f = fopen(buf, "w");
  if (!fp_f) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    exit(1);
  }

  sprintf(buf, "%s/blackscholes-ieee754.out", outputDir);
  fp_ieee754 = fopen(buf, "w");
  if (!fp_ieee754) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    fclose(fp_f);
    exit(1);
  }

  printf("\nBlack-Scholes\n\n");
  blackscholes(inputDir, outputDir, fp_d, fp_f, fp_ieee754);

  fclose(fp_d);
  fclose(fp_f);
  fclose(fp_ieee754);

  //
  // Pink-noise
  //
  sprintf(buf, "%s/pinknoise-double.out", outputDir);
  fp_d = fopen(buf, "w");
  if (!fp_d) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    exit(1);
  }

  sprintf(buf, "%s/pinknoise-float.out", outputDir);
  fp_f = fopen(buf, "w");
  if (!fp_f) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    exit(1);
  }

  sprintf(buf, "%s/pinknoise-ieee754.out", outputDir);
  fp_ieee754 = fopen(buf, "w");
  if (!fp_ieee754) {
    fprintf(stderr, "unable to open file '%s'\n", buf);
    fclose(fp_d);
    fclose(fp_f);
    exit(1);
  }

  printf("\nPink-noise\n\n");
  pink_noise(inputDir, outputDir, fp_d, fp_f, fp_ieee754);

  fclose(fp_d);
  fclose(fp_f);
  fclose(fp_ieee754);

  return;
}

void usage(char *name, const char *message) {
  printf("usage: %s\n", message);
  printf("       %s -i <input directory> -o <output directory> -d <double file> -f <float file> -p <PT-Float-II file>\n", name);
  exit(1);
}

int main(int argc, char **argv) {
  char *inputDir = 0;
  char *outputDir = 0;

  // Process input arguments
  int i;

  if (argc < 5)
    usage(argv[0], "not enough program arguments\n");

  for (i = 1; i < argc; i++) {
    if (argv[i][0] == '-' && !argv[i][2]) {
      if (argv[i][1] == 'i') {
        inputDir = argv[++i];
      } else if (argv[i][1] == 'o') {
        outputDir = argv[++i];
      } else usage(argv[0], "unexpected argument\n");
    } else usage(argv[0], "unexpected argument\n");
  }

  // Run Benchmark
  run_benchmark(inputDir, outputDir);

  return 0;
}
