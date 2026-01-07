#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>
#include <math.h>

#include "ieee754.h"
#include "common.h"

#define MAX_ITER 280

int kmeans_kernel_d(int NDATAPTS, int NCENTRS, int DIM, double * data, unsigned int * label, double * center, double * tempCenter, unsigned int * cluster_size) {

  int i, j, k; // points, centroids and coordinate iterators
  int done; // algorithm done flag

  int loops; // number of iterations of the algorithm
  double minDist, tempDist; // distances from point to centroid
  double updated_center_coordinate;

  // init number of iterations
  loops = 0;
  do{ // new iteration
    // init cluster_size array
    for(j = 0; j < NCENTRS; j++)
      cluster_size[j] = 0;
    // init temporary centers
    for(j = 0; j < NCENTRS; j++)
      for(k=0; k < DIM; k++)
        tempCenter[j*DIM+k]=0;

    for(i = 0; i < NDATAPTS ; i++){
      // init min distance
      minDist = DBL_MAX;
      // compute the distance between the point and each centroid
      for(j = 0; j < NCENTRS; j++){
        for(tempDist=0, k=0; k < DIM; k++)
          tempDist += fabs(data[i*DIM+k] - center[j*DIM+k]);
        if(tempDist < minDist){
          minDist = tempDist;
          label[i] = j;
        }
      }

      // accumulate label cluster_size
      ++cluster_size[label[i]];

      // accumulate point coordinates in respective temp center coordinate
      for(k=0; k < DIM; k++)
        tempCenter[label[i]*DIM+k] += data[i*DIM+k];
    }
    // done computing labels, label cluster_size and accumulated centroid coordinates


    // update the centroids
    done = 1;
    for(j = 0; j < NCENTRS; j++)
      for(k=0; k < DIM; k++){
        updated_center_coordinate = cluster_size[j]? tempCenter[j*DIM+k] / cluster_size[j] : 0;
        if (updated_center_coordinate != center[j*DIM+k]) {
          center[j*DIM+k] = updated_center_coordinate;
          done = 0; // algorithm not finished, another iteration needed
        }
      }
    ++loops;
    if (loops == MAX_ITER) break;
  } while(!done);

  return loops;
}

int kmeans_kernel_f(int NDATAPTS, int NCENTRS, int DIM, float * data, unsigned int * label, float * center, float * tempCenter, unsigned int * cluster_size) {

  int i, j, k; // points, centroids and coordinate iterators
  int done; // algorithm done flag

  int loops; // number of iterations of the algorithm
  float minDist, tempDist; // distances from point to centroid
  float updated_center_coordinate;

  // init number of iterations
  loops = 0;
  do{ // new iteration
    // init cluster_size array
    for(j = 0; j < NCENTRS; j++)
      cluster_size[j] = 0;
    // init temporary centers
    for(j = 0; j < NCENTRS; j++)
      for(k=0; k < DIM; k++)
        tempCenter[j*DIM+k]=0;

    for(i = 0; i < NDATAPTS ; i++){
      // init min distance
      minDist = FLT_MAX;
      // compute the distance between the point and each centroid
      for(j = 0; j < NCENTRS; j++){
        for(tempDist=0, k=0; k < DIM; k++)
          tempDist += (float)fabs((double)(data[i*DIM+k] - center[j*DIM+k]));
        if(tempDist < minDist){
          minDist = tempDist;
          label[i] = j;
        }
      }

      // accumulate label cluster_size
      ++cluster_size[label[i]];

      // accumulate point coordinates in respective temp center coordinate
      for(k=0; k < DIM; k++)
        tempCenter[label[i]*DIM+k] += data[i*DIM+k];
    }
    // done computing labels, label cluster_size and accumulated centroid coordinates


    // update the centroids
    done = 1;
    for(j = 0; j < NCENTRS; j++)
      for(k=0; k < DIM; k++){
        updated_center_coordinate = cluster_size[j]? tempCenter[j*DIM+k] / cluster_size[j] : 0;
        if (updated_center_coordinate != center[j*DIM+k]) {
          center[j*DIM+k] = updated_center_coordinate;
          done = 0; // algorithm not finished, another iteration needed
        }
      }
    ++loops;
    if (loops == MAX_ITER) break;
  } while(!done);

  return loops;
}

int kmeans_kernel_ieee754(int NDATAPTS, int NCENTRS, int DIM, Ieee754 * data, unsigned int * label, Ieee754 * center, Ieee754 * tempCenter, unsigned int * cluster_size) {

  int i, j, k; // points, centroids and coordinate iterators
  int done; // algorithm done flag

  int loops; // number of iterations of the algorithm
  Ieee754 minDist, tempDist; // distances from point to centroid
  Ieee754 updated_center_coordinate;

  // init number of iterations
  loops = 0;
  do{ // new iteration
    // init cluster_size array
    for(j = 0; j < NCENTRS; j++)
      cluster_size[j] = 0;
    // init temporary centers
    for(j = 0; j < NCENTRS; j++)
      for(k=0; k < DIM; k++)
        tempCenter[j*DIM+k]=0;

    for(i = 0; i < NDATAPTS ; i++){
      // init min distance
      minDist = DBL_MAX;
      // compute the distance between the point and each centroid
      for(j = 0; j < NCENTRS; j++){
        for(tempDist=0, k=0; k < DIM; k++)
          tempDist += (Ieee754)fabs((double)(data[i*DIM+k] - center[j*DIM+k]));
        if(tempDist < minDist){
          minDist = tempDist;
          label[i] = j;
        }
      }

      // accumulate label cluster_size
      ++cluster_size[label[i]];

      // accumulate point coordinates in respective temp center coordinate
      for(k=0; k < DIM; k++)
        tempCenter[label[i]*DIM+k] += data[i*DIM+k];
    }
    // done computing labels, label cluster_size and accumulated centroid coordinates


    // update the centroids
    done = 1;
    for(j = 0; j < NCENTRS; j++)
      for(k=0; k < DIM; k++){
        updated_center_coordinate = cluster_size[j]? tempCenter[j*DIM+k] / cluster_size[j] : (Ieee754)0;
        if (updated_center_coordinate != center[j*DIM+k]) {
          center[j*DIM+k] = updated_center_coordinate;
          done = 0; // algorithm not finished, another iteration needed
        }
      }
    ++loops;
    if (loops == MAX_ITER) break;
  } while(!done);

  return loops;
}

void kmeans(char *inputDir, char *outputDir, FILE *fp_d, FILE *fp_f, FILE *fp_ieee754) {

  int NDATAPTS;
  int NCENTRS;
  int DIM;

  double *data_d, *center_d;
  unsigned int *label_d;

  float *data_f, *center_f;
  unsigned int *label_f;

  Ieee754 *data_ieee754, *center_ieee754;
  unsigned int *label_ieee754;

  double *tempCenter_d;
  unsigned int *cluster_size_d;

  float *tempCenter_f;
  unsigned int *cluster_size_f;

  Ieee754 *tempCenter_ieee754;
  unsigned int *cluster_size_ieee754;
  
  int i; // iterators for points, centroids and dimensions
  double *initial_center_d;
  float *initial_center_f;
  Ieee754 *initial_center_ieee754;

  // load data from file
  FILE * fp_data = NULL;
  sprintf(buf, "%s/k-means/data.txt", inputDir);
  fp_data = fopen(buf,"r");
  if (!fp_data) {
    printf("data.txt: no such file\n");
    exit(1);
  }

  fscanf(fp_data, "%d %d %d", &NDATAPTS, &NCENTRS, &DIM);
  printf("NDATAPTS = %d\n", NDATAPTS);
  printf("NCENTRS = %d\n", NCENTRS);
  printf("DIM = %d\n", DIM);

  // allocate space for arrays
  data_d = (double *) malloc(((NDATAPTS+NCENTRS)*DIM)*sizeof(double));
  data_f = (float *) malloc(((NDATAPTS+NCENTRS)*DIM)*sizeof(float));
  data_ieee754 = (Ieee754 *) malloc(((NDATAPTS+NCENTRS)*DIM)*sizeof(Ieee754));
  if (!data_d || !data_f || !data_ieee754) {
    printf("could not allocate data\n");
    exit(1);
  }
  label_d = (unsigned int *) malloc((NDATAPTS)*sizeof(unsigned int));
  label_f = (unsigned int *) malloc((NDATAPTS)*sizeof(unsigned int));
  label_ieee754 = (unsigned int *) malloc((NDATAPTS)*sizeof(unsigned int));
  if (!label_d || !label_f || !label_ieee754) {
    printf("could not allocate data\n");
    exit(1);
  }
  initial_center_d = (double *) malloc((NCENTRS*DIM)*sizeof(double));
  initial_center_f = (float *) malloc((NCENTRS*DIM)*sizeof(float));
  initial_center_ieee754 = (Ieee754 *) malloc((NCENTRS*DIM)*sizeof(Ieee754));
  if (!initial_center_d || !initial_center_f || !initial_center_ieee754) {
    printf("could not allocate initial_center\n");
    exit(1);
  }
  tempCenter_d = (double *) malloc((NCENTRS*DIM)*sizeof(double));
  tempCenter_f = (float *) malloc((NCENTRS*DIM)*sizeof(float));
  tempCenter_ieee754 = (Ieee754 *) malloc((NCENTRS*DIM)*sizeof(Ieee754));
  if (!tempCenter_d || !tempCenter_f || !tempCenter_ieee754) {
    printf("could not allocate tempCenter\n");
    exit(1);
  }
  cluster_size_d = (unsigned int *) malloc(NCENTRS*sizeof(unsigned int));
  cluster_size_f = (unsigned int *) malloc(NCENTRS*sizeof(unsigned int));
  cluster_size_ieee754 = (unsigned int *) malloc(NCENTRS*sizeof(unsigned int));
  if (!cluster_size_d || !cluster_size_f || !cluster_size_ieee754) {
    printf("could not allocate cluster_size\n");
    exit(1);
  }

  // read datapoints
  for(i=0; i < ((NDATAPTS+NCENTRS)*DIM); i++) {
    fscanf(fp_data, "%lF", &data_d[i]);
    data_f[i] = (float)data_d[i];
    data_ieee754[i] = (Ieee754)data_d[i];
  }
  fclose(fp_data);
    
  center_d = data_d + NDATAPTS*DIM;
  bcopy (center_d, initial_center_d, NCENTRS*DIM*sizeof(double));

  center_f = data_f + NDATAPTS*DIM;
  bcopy (center_f, initial_center_f, NCENTRS*DIM*sizeof(float));

  center_ieee754 = data_ieee754 + NDATAPTS*DIM;
  for(i=0; i < NCENTRS*DIM; i++) initial_center_ieee754[i] = center_ieee754[i];

  //
  // Call K-Means
  //
  int loops_d = kmeans_kernel_d(NDATAPTS, NCENTRS, DIM, data_d, label_d, center_d, tempCenter_d, cluster_size_d);
  printf("Iterations on doubles = %d\n", loops_d);

  int loops_f = kmeans_kernel_f(NDATAPTS, NCENTRS, DIM, data_f, label_f, center_f, tempCenter_f, cluster_size_f);
  printf("Iterations on floats = %d\n", loops_f);

  int loops_ieee754 = kmeans_kernel_ieee754(NDATAPTS, NCENTRS, DIM, data_ieee754, label_ieee754, center_ieee754, tempCenter_ieee754, cluster_size_ieee754);
  printf("Iterations on IEEE754s = %d\n", loops_ieee754);

  // Store output data to file
  sprintf(buf, "%s/centers.txt", outputDir);
  fp_data = fopen(buf,"w");
  if (!fp_data) {
    printf("data.txt: no such file\n");
    exit(1);
  }

  for(i=0; i < (NCENTRS*DIM); i++) {
    fprintf(fp_data, "%F\n", center_d[i]);
    fprintf(fp_d, "%.16E\n", center_d[i]);
    fprintf(fp_f, "%.16E\n", center_f[i]);
    fprintf(fp_ieee754, "%.16e\n", center_ieee754[i]);
  }
  fclose(fp_data);

  free(data_d);
  free(label_d);
  free(initial_center_d);
  free(tempCenter_d);
  free(cluster_size_d);

  free(data_f);
  free(label_f);
  free(initial_center_f);
  free(tempCenter_f);
  free(cluster_size_f);

  free(data_ieee754);
  free(label_ieee754);
  free(initial_center_ieee754);
  free(tempCenter_ieee754);
  free(cluster_size_ieee754);

  return;
}
