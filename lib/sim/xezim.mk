
incdir:=-I
defmacro:=-D

include $(FPU_DIR)/lib/sim/simulation.mk

# xezim stops at 100ms of simulated time by default; run until $finish
XEZIM_MAX_TIME?=1000s
VFLAGS=--max-time $(XEZIM_MAX_TIME) -s $(TB_TOP)

run: $(VSRC) $(VHDR)
	xezim $(VFLAGS) $(INCLUDE) $(DEFINE) $(VSRC)

comp: $(VSRC) $(VHDR)
	xezim --compile $(VFLAGS) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -f *~ *.vcd

.PHONY: run comp clean
