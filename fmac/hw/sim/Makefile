CORE:=fmac
FPU_DIR:=../../..

include $(FPU_DIR)/lib/sim/sim.mk

STREAM_N?=6000

streams:
	python3 src/fmac_streams.py gen $(STREAM_N) streams.tv
	$(MAKE) --no-print-directory clean
	$(MAKE) --no-print-directory run STREAMS=1 > streams.rpt 2>&1
	@python3 src/fmac_streams.py check streams.tv streams.out

# random streams of the formats MODEL_FMTS in each mode, checked bit for bit against the
# C model (sw_model/tests/mac_vectors.c)
MODEL_FMTS?=fp4 fp6 e4m3 e5m2
MODEL_N?=3000
MAC_VECTORS=$(abspath $(FPU_DIR)/sw_model/build/mac_vectors)

$(MAC_VECTORS):
	$(MAKE) -C $(FPU_DIR)/sw_model build/mac_vectors

streams-model: $(MAC_VECTORS)
	@status=0; for fmt in $(MODEL_FMTS); do for m in $(TF_MODES); do \
	  case $$fmt in fp4) w="4 2";; fp6) w="6 3";; e4m3) w="8 4";; e5m2) w="8 5";; \
	    f16) w="16 5";; f32) w="32 8";; f64) w="64 11";; *) echo "unknown format $$fmt"; exit 1;; esac; \
	  case $$m in rne) r=0;; rtz) r=1;; rdn) r=2;; rup) r=3;; rmm) r=4;; *) echo "unknown mode $$m"; exit 1;; esac; \
	  $(MAC_VECTORS) $$w $$r $(MODEL_N) streams.tv streams.exp; \
	  $(MAKE) --no-print-directory clean; \
	  $(MAKE) --no-print-directory run STREAMS=1 TF_FMT=$$fmt ST_RND=$$r > streams_$${fmt}_$$m.rpt 2>&1; \
	  bad=$$(diff streams.out streams.exp | grep -c '^>'); \
	  echo "fmac streams $$fmt $$m: streams=$(MODEL_N) mismatches=$$bad"; \
	  [ "$$bad" = 0 ] && [ $$(wc -l < streams.out) = $(MODEL_N) ] || status=1; \
	done; done; rm -f streams.tv streams.exp streams.out; $(MAKE) --no-print-directory clean; exit $$status

streams-clean:
	@rm -f streams.tv streams.out streams.exp streams*.rpt fails_streams.tv

.PHONY: streams streams-model streams-clean
