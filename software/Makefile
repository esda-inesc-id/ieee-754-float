ROOT_DIR:=.
SW_DIR=$(ROOT_DIR)
PYTHON_DIR=$(SW_DIR)/python
TRG:=ieee754_tests

CPP=g++

ARFLAGS=rcs

include $(SW_DIR)/pc/ieee754.mk

SRC+=$(SW_DIR)/pc/$(TRG).cpp

OBJ:=$(SRC:.cpp=.o)

FP_DATA_W=$(shell grep "define FP_DATA_W" $(SW_DIR)/ieee754lib.h | awk '{print $$3}')
FP_EXP_W=$(shell grep "define FP_EXP_W" $(SW_DIR)/ieee754lib.h | awk '{print $$3}')

test: clean-all $(TRG)
	./$(TRG) -i data.in -w weights.in -d ./$@-double.out -f ./$@-float.out -p ./$@-ieee754.out
#	./$(TRG) -d ./$@-double.out -f ./$@-float.out -p ./$@-ieee754.out
#	$(PYTHON_DIR)/floatVSieee754 -d ./$@-double.out -f ./$@-float.out -o ./float-floatVSieee754.out -p 16 -dw $(FP_DATA_W) -esw $(FP_EXP_W)
#	$(PYTHON_DIR)/floatVSieee754 -d ./$@-double.out -ptf3 ./$@-ieee754.out -o ./ieee754-floatVSieee754.out -p 16 -dw $(FP_DATA_W) -esw $(FP_EXP_W)

$(TRG): $(OBJ) $(SW_DIR)/pc/ieee754.a
	$(CPP) $^ -o $@

%.o: %.cpp
	$(CPP) -Wall -O3 $(INCLUDE) -c $< -o $@

clean:
	rm -f $(TRG)
	rm -f *.out *.summary
	rm -rf $(PYTHON_DIR)/__pycache__
	find . -name "*.o" -type f -delete
	@find . -name "*~" -type f -delete
	@find . -name "*#" -type f -delete

clean-all: clean

.PHONY: test clean clean-all
