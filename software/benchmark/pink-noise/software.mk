PINKNOISE_DIR=$(BENCH_DIR)/pink-noise

# Search paths
INCLUDE+=-I$(PINKNOISE_DIR)

# Headers
HDR+=$(PINKNOISE_DIR)/pink-noise.h

# Sources
SRC+=$(PINKNOISE_DIR)/pink-noise.cpp
