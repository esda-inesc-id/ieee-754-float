KMEANS_DIR=$(BENCH_DIR)/k-means

# Search paths
INCLUDE+=-I$(KMEANS_DIR)

# Headers
HDR+=$(KMEANS_DIR)/k-means.h

# Sources
SRC+=$(KMEANS_DIR)/k-means.cpp
