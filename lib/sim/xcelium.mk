
empty:=
space:=$(empty) $(empty)
incdir:=-incdir$(space)
defmacro:=-define$(space)

include $(FPU_DIR)/lib/sim/simulation.mk

COMMON_FLAGS=-errormax 15 -status
SFLAGS=$(COMMON_FLAGS) -licqueue
EFLAGS=$(SFLAGS) -access +wc
VFLAGS=$(COMMON_FLAGS) -update -linedebug -sv

run: comp
	xmsim $(SFLAGS) worklib.$(TB_TOP):module

comp: $(VSRC) $(VHDR)
	xmvlog $(VFLAGS) $(INCLUDE) $(DEFINE) $(VSRC)
	xmelab $(EFLAGS) worklib.$(TB_TOP):module

clean:
	@rm -rf *~ *.vcd *.log *.key *.history xcelium.d

.PHONY: run comp clean
