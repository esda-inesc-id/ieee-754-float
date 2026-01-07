ROOT_DIR:=.
SW_DIR=$(ROOT_DIR)
BENCH_DIR=$(SW_DIR)/benchmark
PYTHON_DIR=$(SW_DIR)/python

CPP=g++

include $(SW_DIR)/pc/ieee754.mk

ifeq ($(BENCH),1)
TRG:=bench
USE_ACC=0
include $(BENCH_DIR)/benchmark.mk
else
TRG:=ieee754_tests
SRC+=$(SW_DIR)/pc/$(TRG).cpp
endif

USE_ACC?=1
ifeq ($(USE_ACC),1)
DEFINE+=-DUSE_ACC
endif

OBJ:=$(SRC:.cpp=.o)

IEEE754_DATA_W=$(shell grep "define IEEE754_DATA_W" $(SW_DIR)/ieee754lib.h | awk '{print $$3}')
IEEE754_EXP_W=$(shell grep "define IEEE754_EXP_W" $(SW_DIR)/ieee754lib.h | awk '{print $$3}')

test: clean-all $(TRG)
	./$(TRG) -i data.in -w weights.in -d ./$@-double.out -f ./$@-float.out -p ./$@-ieee754.out
#	./$(TRG) -d ./$@-double.out -f ./$@-float.out -p ./$@-ieee754.out
#	$(PYTHON_DIR)/floatVSieee754 -d ./$@-double.out -f ./$@-float.out -o ./float-floatVSieee754.out -p 16 -dw $(IEEE754_DATA_W) -ew $(IEEE754_EXP_W)
#	$(PYTHON_DIR)/floatVSieee754 -d ./$@-double.out -ieee754 ./$@-ieee754.out -o ./ieee754-floatVSieee754.out -p 16 -dw $(IEEE754_DATA_W) -ew $(IEEE754_EXP_W)

benchmark: clean-all $(TRG)
	./$(TRG) -i $(BENCH_DIR) -o $(BENCH_DIR)
	@make evaluate

evaluate:
	@echo "Evaluating benchmarks:"
	$(eval apps = $(shell ls benchmark/*-double.out | cut -d/ -f2 | cut -d- -f1))
	@for app in $(apps);\
	do \
	echo -n "$$app...";\
	$(PYTHON_DIR)/floatVSieee754 -d ./benchmark/$$app-double.out -f ./benchmark/$$app-float.out -o ./$$app-float-floatVSieee754.out -p 16 -dw $(IEEE754_DATA_W) -ew $(IEEE754_EXP_W);\
	$(PYTHON_DIR)/floatVSieee754 -d ./benchmark/$$app-double.out -ieee754 ./benchmark/$$app-ieee754.out -o ./$$app-ieee754-floatVSieee754.out -p 16 -dw $(IEEE754_DATA_W) -ew $(IEEE754_EXP_W);\
	echo "done" ;\
	done

$(TRG): $(OBJ) $(SW_DIR)/pc/ieee754.a
	$(CPP) $^ -o $@

%.o: %.cpp
	$(CPP) -Wall -O3 $(INCLUDE) $(DEFINE) -c $< -o $@

clean:
	rm -f $(TRG) bench
	rm -f *.out *.summary
	rm -rf $(PYTHON_DIR)/__pycache__
	find . -name "*.o" -type f -delete
	rm -f benchmark/*.txt benchmark/*.out
	@find . -name "*~" -type f -delete
	@find . -name "*#" -type f -delete

clean-all: clean clean-ieee754

.PHONY: test \
	benchmark evaluate \
	clean clean-all
