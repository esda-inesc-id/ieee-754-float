include $(BENCH_DIR)/dp/software.mk
include $(BENCH_DIR)/newton-raph/software.mk
include $(BENCH_DIR)/fft/software.mk
include $(BENCH_DIR)/k-means/software.mk
include $(BENCH_DIR)/black-scholes/software.mk
include $(BENCH_DIR)/pink-noise/software.mk

# Search paths
INCLUDE+=-I$(BENCH_DIR)
INCLUDE+=-I$(BENCH_DIR)/common

# Includes
HDR+=$(BENCH_DIR)/benchmark.h

# Sources
SRC+=$(BENCH_DIR)/benchmark.cpp
SRC+=$(BENCH_DIR)/common/common.cpp
