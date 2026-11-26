# Software model of the IEEE-754 units.
#
# make run CPROG=<example>|all|ieee754_tests   build and run a C++ program
# make run PYPROG=<program> ARGS="..."         run a program in python/
# make test                                    self-checks and math library accuracy,
#                                              needs no RTL tools
# make check                                   bit-accuracy against TestFloat and the RTL
# make fmac-accuracy                            fmac accuracy study (needs MPFR)
# make fma-formats                              ffma test, FP4 to binary128 (needs MPFR)
# make clean

CC=gcc
CXX=g++
PYTHON=python3

BUILD_DIR?=build
RTL_DIR?=..
ABS_BUILD_DIR:=$(abspath $(BUILD_DIR))

EXAMPLES:=dp newton-raph fft k-means black-scholes pink-noise
CPROG?=all

CFLAGS=-std=c11 -D_GNU_SOURCE -Wall -Wextra -O2 -fPIC -Ic
CXXFLAGS=-std=c++11 -Wall -O2 -Ic -Icpp -Iexamples -Iexamples/common $(addprefix -Iexamples/,$(EXAMPLES))

MODEL_HDR:=c/ieee754_model.h c/ieee754_math.h c/ieee754_mac.inc
MODEL_OBJ:=$(BUILD_DIR)/ieee754_model.o $(BUILD_DIR)/ieee754_math.o
LIB:=$(BUILD_DIR)/libieee754.so
MODEL_RUN:=$(BUILD_DIR)/model_run
TESTS:=$(BUILD_DIR)/ieee754_tests
MATH_ACCURACY:=$(BUILD_DIR)/math_accuracy
BENCH:=$(BUILD_DIR)/bench
GEN_INPUTS:=$(BUILD_DIR)/gen_inputs
# synthetic example inputs, generated from a fixed seed
INPUTS:=$(BUILD_DIR)/in/.done
CXX_HDR:=cpp/ieee754.h $(MODEL_HDR) examples/common/common.h

BENCH_SRC:=examples/benchmark.cpp examples/common/common.cpp $(foreach e,$(EXAMPLES),examples/$(e)/$(e).cpp)
BENCH_OBJ:=$(patsubst %.cpp,$(BUILD_DIR)/%.o,$(BENCH_SRC))
TESTS_OBJ:=$(BUILD_DIR)/tests/ieee754_tests.o $(BUILD_DIR)/examples/common/common.o

ifdef PYPROG
run: $(LIB)
	IEEE754_LIB=$(abspath $(LIB)) $(PYTHON) python/$(PYPROG) $(ARGS)
else ifeq ($(CPROG),ieee754_tests)
run: run-tests
else
run: $(BENCH) $(LIB) $(INPUTS)
	@rm -rf $(BUILD_DIR)/out
	@mkdir -p $(BUILD_DIR)/out
	$(BENCH) -i $(BUILD_DIR)/in -o $(BUILD_DIR)/out -e $(CPROG)
	@echo "outputs in $(BUILD_DIR)/out"
endif

run-tests: $(TESTS)
	$(TESTS)

run-math-accuracy: $(MATH_ACCURACY)
	$(MATH_ACCURACY)

test: run-tests run-math-accuracy

FMAC_ACCURACY:=$(BUILD_DIR)/fmac_accuracy

fmac-accuracy: $(FMAC_ACCURACY)
	$(FMAC_ACCURACY) | tee $(BUILD_DIR)/fmac_accuracy.txt

$(FMAC_ACCURACY): study/fmac_accuracy.c $(MODEL_OBJ) $(MODEL_HDR)
	$(CC) $(CFLAGS) -ffp-contract=off study/fmac_accuracy.c $(MODEL_OBJ) -lmpfr -lgmp -lm -o $@

FMA_FORMATS:=$(BUILD_DIR)/fma_formats

# ffma/fmac test: FP4, FP6, FP8 exhaustive; bfloat16 to binary128 random (needs MPFR)
fma-formats: $(FMA_FORMATS)
	$(FMA_FORMATS)

$(FMA_FORMATS): tests/fma_formats.c $(MODEL_OBJ) $(MODEL_HDR)
	$(CC) $(CFLAGS) -ffp-contract=off tests/fma_formats.c $(MODEL_OBJ) -lmpfr -lgmp -lm -o $@

check: $(MODEL_RUN) $(LIB)
	IEEE754_LIB=$(abspath $(LIB)) $(PYTHON) tests/check.py --rtl $(RTL_DIR) \
	  --work $(ABS_BUILD_DIR)/check --model-run $(MODEL_RUN)

$(BUILD_DIR)/%.o: c/%.c $(MODEL_HDR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(LIB): $(MODEL_OBJ)
	$(CC) -shared $^ -lm -o $@

$(MATH_ACCURACY): tests/math_accuracy.c $(MODEL_OBJ) $(MODEL_HDR)
	$(CC) $(CFLAGS) tests/math_accuracy.c $(MODEL_OBJ) -lm -o $@

$(MODEL_RUN): tests/model_run.c $(MODEL_OBJ) $(MODEL_HDR)
	$(CC) $(CFLAGS) tests/model_run.c $(MODEL_OBJ) -lm -o $@

$(BENCH): $(BENCH_OBJ) $(MODEL_OBJ)
	$(CXX) $^ -lm -o $@

$(TESTS): $(TESTS_OBJ) $(MODEL_OBJ)
	$(CXX) $^ -lm -o $@

$(GEN_INPUTS): examples/common/gen_inputs.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $< -o $@

$(INPUTS): $(GEN_INPUTS)
	$(GEN_INPUTS) $(BUILD_DIR)/in
	@touch $@

$(BUILD_DIR)/%.o: %.cpp $(CXX_HDR)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR) python/__pycache__ tests/__pycache__

.PHONY: run run-tests run-math-accuracy test check fmac-accuracy clean
