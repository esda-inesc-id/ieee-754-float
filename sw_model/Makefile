# Software model of the IEEE-754 units.
#
# make run CPROG=<example>|all|ieee754_tests   build and run a C++ program
# make run PYPROG=<program> ARGS="..."         run a program in python/
# make test                                    self-checks, needs no RTL tools
# make check                                   bit-accuracy against TestFloat and the RTL
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

MODEL_SRC:=c/ieee754_model.c
MODEL_HDR:=c/ieee754_model.h
MODEL_OBJ:=$(BUILD_DIR)/ieee754_model.o
LIB:=$(BUILD_DIR)/libieee754.so
MODEL_RUN:=$(BUILD_DIR)/model_run
TESTS:=$(BUILD_DIR)/ieee754_tests
BENCH:=$(BUILD_DIR)/bench
CXX_HDR:=cpp/ieee754.h $(MODEL_HDR) examples/common/common.h

BENCH_SRC:=examples/benchmark.cpp examples/common/common.cpp $(foreach e,$(EXAMPLES),examples/$(e)/$(e).cpp)
BENCH_OBJ:=$(patsubst %.cpp,$(BUILD_DIR)/%.o,$(BENCH_SRC))
TESTS_OBJ:=$(BUILD_DIR)/tests/ieee754_tests.o $(BUILD_DIR)/examples/common/common.o

COMPARE=IEEE754_LIB=$(abspath $(LIB)) $(PYTHON) python/floatVSieee754 -p 16

ifdef PYPROG
run: $(LIB)
	IEEE754_LIB=$(abspath $(LIB)) $(PYTHON) python/$(PYPROG) $(ARGS)
else ifeq ($(CPROG),ieee754_tests)
run: run-tests
else
run: $(BENCH) $(LIB)
	@rm -rf $(BUILD_DIR)/out
	@mkdir -p $(BUILD_DIR)/out
	$(BENCH) -i examples -o $(BUILD_DIR)/out -e $(CPROG)
	@for ref in $(BUILD_DIR)/out/*-double.out; do \
	  app=$$(basename $$ref -double.out); \
	  $(COMPARE) -d $$ref -f $(BUILD_DIR)/out/$$app-float.out -o $(BUILD_DIR)/out/$$app-float.cmp || exit 1; \
	  $(COMPARE) -d $$ref -ieee754 $(BUILD_DIR)/out/$$app-ieee754.out -o $(BUILD_DIR)/out/$$app-ieee754.cmp || exit 1; \
	  echo "$$app: float $$(grep -h '^diffs' $(BUILD_DIR)/out/$$app-float.cmp), ieee754 $$(grep -h '^diffs' $(BUILD_DIR)/out/$$app-ieee754.cmp)"; \
	done
endif

run-tests: $(TESTS) $(LIB)
	@mkdir -p $(BUILD_DIR)/out
	$(TESTS) -i examples/dp/data.in -w examples/dp/weights.in \
	  -d $(BUILD_DIR)/out/test-double.out -f $(BUILD_DIR)/out/test-float.out \
	  -p $(BUILD_DIR)/out/test-ieee754.out
	$(COMPARE) -d $(BUILD_DIR)/out/test-double.out -f $(BUILD_DIR)/out/test-float.out \
	  -o $(BUILD_DIR)/out/test-float.cmp
	$(COMPARE) -d $(BUILD_DIR)/out/test-double.out -ieee754 $(BUILD_DIR)/out/test-ieee754.out \
	  -o $(BUILD_DIR)/out/test-ieee754.cmp
	@tail -n 2 $(BUILD_DIR)/out/test-ieee754.cmp

test: run-tests

check: $(MODEL_RUN) $(LIB)
	IEEE754_LIB=$(abspath $(LIB)) $(PYTHON) tests/check.py --rtl $(RTL_DIR) \
	  --work $(ABS_BUILD_DIR)/check --model-run $(MODEL_RUN)

$(MODEL_OBJ): $(MODEL_SRC) $(MODEL_HDR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(LIB): $(MODEL_OBJ)
	$(CC) -shared $^ -lm -o $@

$(MODEL_RUN): tests/model_run.c $(MODEL_OBJ) $(MODEL_HDR)
	$(CC) $(CFLAGS) tests/model_run.c $(MODEL_OBJ) -lm -o $@

$(BENCH): $(BENCH_OBJ) $(MODEL_OBJ)
	$(CXX) $^ -lm -o $@

$(TESTS): $(TESTS_OBJ) $(MODEL_OBJ)
	$(CXX) $^ -lm -o $@

$(BUILD_DIR)/%.o: %.cpp $(CXX_HDR)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR) python/__pycache__ tests/__pycache__

.PHONY: run run-tests test check clean
