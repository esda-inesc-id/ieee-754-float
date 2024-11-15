FPU_DIR:=../../..

incdir:=-i 
defmacro:=-d 

include ../simulation.mk

CFLAGS=--sv
EFLAGS=--dup_entity_as_module --snapshot
SFLAGS=--R

run: elab
	xsim $(SFLAGS) worklib

elab: comp
	xelab $(EFLAGS) worklib $(TOP_MODULE)_tb

comp: $(VSRC) $(VHDR)
	xvlog $(CFLAGS) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -rf *~ *.vcd xsim.dir *.jou *.log *.pb

.PHONY: run comp elab clean
