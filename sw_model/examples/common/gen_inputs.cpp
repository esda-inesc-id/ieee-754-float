// Generates the synthetic input data of the examples, from a fixed seed, so the
// results are the same on every run.
//
// usage: gen_inputs <output directory>
// writes <dir>/{black-scholes,dp,fft,k-means,newton-raph}/<input files>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <string>
#include <sys/stat.h>

static std::mt19937_64 rng(20261124);

// Uniform in [lo, hi), from the top 53 bits of the generator
static double uniform(double lo, double hi) {
  return lo + (hi - lo) * (double)(rng() >> 11) / 9007199254740992.0;
}

// Uniform integer in [lo, hi]
static long integer(long lo, long hi) { return lo + (long)(rng() % (uint64_t)(hi - lo + 1)); }

static FILE *open_file(const std::string &dir, const char *example, const char *name,
                       const char *mode) {
  std::string path = dir + "/" + example;
  mkdir(path.c_str(), 0755);
  path += std::string("/") + name;
  FILE *fp = fopen(path.c_str(), mode);
  if (!fp) {
    fprintf(stderr, "gen_inputs: cannot write %s\n", path.c_str());
    exit(1);
  }
  return fp;
}

// Option parameters in the ranges of the PARSEC black-scholes inputs: spot price,
// strike, rate, dividend rate, volatility, time, type, dividend value and an unused
// reference value
static void black_scholes(const std::string &dir) {
  const int n = 200000;
  FILE *fp = open_file(dir, "black-scholes", "data_in.txt", "w");
  fprintf(fp, "%d\n", n);
  for (int i = 0; i < n; i++) {
    double s = integer(40, 110);
    double strike = integer(40, 110);
    double r = uniform(0.0275, 0.1);
    double v = uniform(0.05, 0.65);
    double t = uniform(0.05, 1.0);
    char type = integer(0, 1) ? 'C' : 'P';
    fprintf(fp, "%.2f %.2f %.4f 0.00 %.2f %.2f %c 0.00 0.0\n", s, strike, r, v, t, type);
  }
  fclose(fp);
}

// Binary files: an int count, then that many floats
static void write_floats(const std::string &dir, const char *name, int n, double lo, double hi) {
  FILE *fp = open_file(dir, "dp", name, "wb");
  fwrite(&n, sizeof n, 1, fp);
  for (int i = 0; i < n; i++) {
    float x = (float)uniform(lo, hi);
    fwrite(&x, sizeof x, 1, fp);
  }
  fclose(fp);
}

static void dp(const std::string &dir) {
  write_floats(dir, "data.in", 2352, 0.1, 0.825);
  write_floats(dir, "weights.in", 27, -0.235, 0.301);
}

// A sampled sine as the complex input, and the twiddle factors exp(-2 pi i k / n)
static void fft(const std::string &dir) {
  const int n = 32768;
  const double pi = 3.14159265358979323846;
  FILE *fp = open_file(dir, "fft", "x.txt", "w");
  fprintf(fp, "%d\n", n);
  for (int i = 0; i < n; i++) fprintf(fp, "%.17g\n0.0\n", std::sin(2 * pi * 0.0103 * i));
  fclose(fp);

  fp = open_file(dir, "fft", "w.txt", "w");
  fprintf(fp, "%d\n", n / 2);
  for (int k = 0; k < n / 2; k++)
    fprintf(fp, "%.17g\n%.17g\n", std::cos(2 * pi * k / n), -std::sin(2 * pi * k / n));
  fclose(fp);
}

// Points, centers and dimensions, then (points + centers) * dimensions values in [-1, 1)
static void k_means(const std::string &dir) {
  const int points = 10064, centers = 34, dims = 30;
  FILE *fp = open_file(dir, "k-means", "data.txt", "w");
  fprintf(fp, "%d %d %d\n", points, centers, dims);
  for (int i = 0; i < (points + centers) * dims; i++) fprintf(fp, "%.17g\n", uniform(-1, 1));
  fclose(fp);
}

// Integer coefficients of cubics A x^3 + B x^2 + C x + D and a starting point x0
static void newton_raph(const std::string &dir) {
  const int n = 32768;
  FILE *fp = open_file(dir, "newton-raph", "coeff_in.txt", "w");
  fprintf(fp, "%d\n", n);
  for (int i = 0; i < n; i++) {
    long a = integer(0, 20), b = integer(0, 20), c = integer(0, 20);
    long d = integer(-6000, -2000), x0 = integer(0, 15000);
    fprintf(fp, "%ld.000000 %ld.000000 %ld.000000 %ld.000000 %ld.000000\n", a, b, c, d, x0);
  }
  fclose(fp);
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: gen_inputs <output directory>\n");
    return 1;
  }
  std::string dir = argv[1];
  mkdir(dir.c_str(), 0755);
  black_scholes(dir);
  dp(dir);
  fft(dir);
  k_means(dir);
  newton_raph(dir);
  return 0;
}
