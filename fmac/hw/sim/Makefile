CORE:=fmac
FPU_DIR:=../../..

include $(FPU_DIR)/lib/sim/sim.mk

STREAM_N?=6000

streams:
	python3 src/fmac_streams.py gen $(STREAM_N) streams.tv
	$(MAKE) --no-print-directory clean
	$(MAKE) --no-print-directory run STREAMS=1 > streams.rpt 2>&1
	@python3 src/fmac_streams.py check streams.tv streams.out

streams-clean:
	@rm -f streams.tv streams.out streams.rpt fails_streams.tv

.PHONY: streams streams-clean
