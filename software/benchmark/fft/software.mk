FFT_DIR=$(BENCH_DIR)/fft

# Search paths
INCLUDE+=-I$(FFT_DIR)

# Headers
HDR+=$(FFT_DIR)/fft.h

# Sources
SRC+=$(FFT_DIR)/fft.cpp
