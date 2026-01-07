BS_DIR=$(BENCH_DIR)/black-scholes

# Search paths
INCLUDE+=-I$(BS_DIR)

# Headers
HDR+=$(BS_DIR)/black-scholes.h

# Sources
SRC+=$(BS_DIR)/black-scholes.cpp
