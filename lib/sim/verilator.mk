incdir:=-I
defmacro:=-D

include $(FPU_DIR)/lib/sim/simulation.mk

# Verilator 5 with --timing runs the event-driven testbenches. COV=1 adds line,
# branch and toggle coverage; each run writes its data to cov/ for make coverage.
VERILATOR_FLAGS=--binary --timing -j 0 -O2 --top-module $(TB_TOP) -Wno-fatal -Wno-lint -Wno-style \
  -Wno-MULTIDRIVEN -Wno-INITIALDLY --Mdir obj_dir
ifeq ($(COV),1)
VERILATOR_FLAGS+=--coverage-line --coverage-toggle
COV_DIR=cov
COV_FILE=$(COV_DIR)/$(TB_TOP)_$(TF_FMT)_$(TF_OP)_$(TF_RND)_$(STREAMS)$(FPU_MIX).dat
COV_RUN=+verilator+coverage+file+$(COV_FILE)
endif

run: obj_dir/V$(TB_TOP)
ifeq ($(COV),1)
	@mkdir -p $(COV_DIR)
endif
	./obj_dir/V$(TB_TOP) $(COV_RUN)

obj_dir/V$(TB_TOP): $(VSRC) $(VHDR)
	verilator $(VERILATOR_FLAGS) $(INCLUDE) $(DEFINE) $(VSRC) > verilator_build.log 2>&1 || \
	  { tail -30 verilator_build.log; exit 1; }

clean:
	@rm -rf *~ *.vcd obj_dir verilator_build.log

.PHONY: run clean
