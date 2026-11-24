
incdir:=-i 
defmacro:=-d 

include $(FPU_DIR)/lib/sim/simulation.mk

VFLAGS=--sv
EFLAGS=--dup_entity_as_module --snapshot
SFLAGS=--R

run: elab
	xsim $(SFLAGS) worklib

elab: comp
	xelab $(EFLAGS) worklib $(TB_TOP)

comp: verilog

verilog: $(VSRC) $(VHDR)
	xvlog $(VFLAGS) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -rf *~ *.vcd xsim.dir *.jou *.log *.pb

.PHONY: \
	comp verilog \
	elab \
	run \
	clean
