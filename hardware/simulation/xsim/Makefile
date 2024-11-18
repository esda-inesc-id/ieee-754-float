FPU_DIR:=../../..

incdir:=-i 
defmacro:=-d 

include ../simulation.mk

VFLAGS=--sv
VHDLFLAGS=--2008
EFLAGS=--dup_entity_as_module --snapshot
SFLAGS=--R

run: elab
	xsim $(SFLAGS) worklib

elab: comp
	xelab $(EFLAGS) worklib $(TOP_MODULE)_tb

comp: verilog
ifeq ($(FLOPOCO),1)
	make vhdl
	cp $(FPU_HW_DIR)/src/testbench/$(TOP_MODULE).input .
endif

verilog: $(VSRC) $(VHDR)
	xvlog $(VFLAGS) $(INCLUDE) $(DEFINE) $(VSRC)

vhdl: $(VHDLSRC)
	xvhdl $(VHDLFLAGS) $(VHDLSRC)

clean:
	@rm -rf *~ *.vcd xsim.dir *.jou *.log *.pb

.PHONY: \
	comp verilog vhdl \
	elab \
	run \
	clean
