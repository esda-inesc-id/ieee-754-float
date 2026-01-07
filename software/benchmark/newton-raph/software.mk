NR_DIR=$(BENCH_DIR)/newton-raph

# Search paths
INCLUDE+=-I$(NR_DIR)

# Headers
HDR+=$(NR_DIR)/newton-raph.h

# Sources
SRC+=$(NR_DIR)/newton-raph.cpp
