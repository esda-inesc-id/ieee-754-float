SW_DIR?=..

CPP=g++
AR=ar

ARFLAGS=rcs

# Search paths
INCLUDE+=-I$(SW_DIR)
INCLUDE+=-I.

# Headers
HDR+=$(SW_DIR)/ieee754lib.h
HDR+=ieee754.h

# Sources
SRC+=ieee754lib.c
SRC+=ieee754.cpp

OBJ:=$(SRC:.c=.o)
OBJ:=$(OBJ:.cpp=.o)

ieee754.a: $(OBJ)
	$(AR) $(ARFLAGS) $@ $^

%.o: %.cpp
	$(CPP) -Wall -O3 $(INCLUDE) -c $< -o $@

%.o: %.c
	$(CPP) -Wall -O3 $(INCLUDE) -c $< -o $@

clean:
	rm -f ieee754.a *.o *~

.PHONY: clean
