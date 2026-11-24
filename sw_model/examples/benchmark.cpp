// Runs one example or all of them, writing <prefix>-{double,float,ieee754}.out files.
//
// usage: bench -i <input directory> -o <output directory> [-e <example>]

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "benchmark.h"
#include "common.h"

typedef void (*example_fn)(char *, char *, FILE *, FILE *, FILE *);

struct Example {
  const char *name;
  const char *prefix;
  const char *title;
  example_fn run;
};

static const Example examples[] = {
    {"dp", "dp", "Dot Product", dp},
    {"newton-raph", "nr", "Newton-Raphson", nr},
    {"fft", "fft", "Fast Fourier Transform", fft},
    {"k-means", "kmeans", "k-Means Clustering", kmeans},
    {"black-scholes", "blackscholes", "Black-Scholes", blackscholes},
    {"pink-noise", "pinknoise", "Pink-noise", pink_noise},
};

static FILE *open_output(const char *dir, const char *prefix, const char *kind) {
  char path[1024];
  snprintf(path, sizeof path, "%s/%s-%s.out", dir, prefix, kind);
  FILE *fp = fopen(path, "w");
  if (!fp) {
    fprintf(stderr, "unable to open file '%s'\n", path);
    exit(1);
  }
  return fp;
}

static void run_example(const Example &example, char *input_dir, char *output_dir) {
  FILE *fp_d = open_output(output_dir, example.prefix, "double");
  FILE *fp_f = open_output(output_dir, example.prefix, "float");
  FILE *fp_ieee754 = open_output(output_dir, example.prefix, "ieee754");

  printf("\n%s\n\n", example.title);
  example.run(input_dir, output_dir, fp_d, fp_f, fp_ieee754);

  fclose(fp_d);
  fclose(fp_f);
  fclose(fp_ieee754);
}

static void usage(const char *name, const char *message) {
  printf("%s\n", message);
  printf("usage: %s -i <input directory> -o <output directory> [-e <example>]\n", name);
  exit(1);
}

int main(int argc, char **argv) {
  char *input_dir = 0;
  char *output_dir = 0;
  const char *selected = "all";

  for (int i = 1; i < argc; i++) {
    if (i + 1 >= argc) usage(argv[0], "missing argument value");
    if (!strcmp(argv[i], "-i")) {
      input_dir = argv[++i];
    } else if (!strcmp(argv[i], "-o")) {
      output_dir = argv[++i];
    } else if (!strcmp(argv[i], "-e")) {
      selected = argv[++i];
    } else {
      usage(argv[0], "unexpected argument");
    }
  }
  if (!input_dir || !output_dir) usage(argv[0], "not enough arguments");

  int found = 0;
  for (const Example &example : examples) {
    if (!strcmp(selected, "all") || !strcmp(selected, example.name)) {
      run_example(example, input_dir, output_dir);
      found = 1;
    }
  }
  if (!found) usage(argv[0], "unknown example");
  return 0;
}
