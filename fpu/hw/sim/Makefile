CORE:=fpu
FPU_DIR:=../../..

include $(FPU_DIR)/lib/sim/sim.mk

MIX_N?=100000

mix: $(TF_GEN)
	python3 src/fpu_mix.py $(TF_GEN) $(MIX_N) mix.tv
	$(MAKE) --no-print-directory clean
	$(MAKE) --no-print-directory run FPU_MIX=1 > mix.rpt 2>&1
	@grep -h 'FPU_MIX' mix.rpt | tail -1
	@grep -Eq 'FPU_MIX vectors=[1-9][0-9]* received=[0-9]+ fails=0$$' mix.rpt

mix-clean:
	@rm -f mix.tv mix.rpt fails_mix.tv

.PHONY: mix mix-clean
