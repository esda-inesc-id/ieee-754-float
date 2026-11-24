# Berkeley TestFloat: generates vectors with SoftFloat and checks the unit.
# The tools are fetched at fixed versions and built in lib/sim/testfloat-build.

TF_LEVEL?=1
# rounding modes tested, by name; TF_RND is the rnd_mode value of one run
TF_MODES?=rne rtz rdn rup rmm
TF_RND?=0
# formats tested: f16, f32 and f64
TF_FMTS?=f32
# keep only the first TF_N vectors (smoke test); empty runs the full level
TF_N?=
TF_BUILD=$(abspath $(FPU_DIR)/lib/sim/testfloat-build)
TF_GEN=$(TF_BUILD)/berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen
SOFTFLOAT_SHA=07ebd29db0cfb55723a79fbbffe99103ef38e305
TESTFLOAT_SHA=a9c849f1b0eb0264b626d9686ffae167d996e3be

$(TF_GEN):
	mkdir -p $(TF_BUILD)
	[ -d $(TF_BUILD)/berkeley-softfloat-3 ] || git clone -q https://github.com/ucb-bar/berkeley-softfloat-3.git $(TF_BUILD)/berkeley-softfloat-3
	[ -d $(TF_BUILD)/berkeley-testfloat-3 ] || git clone -q https://github.com/ucb-bar/berkeley-testfloat-3.git $(TF_BUILD)/berkeley-testfloat-3
	cd $(TF_BUILD)/berkeley-softfloat-3 && git checkout -q $(SOFTFLOAT_SHA)
	cd $(TF_BUILD)/berkeley-testfloat-3 && git checkout -q $(TESTFLOAT_SHA)
	$(MAKE) -C $(TF_BUILD)/berkeley-softfloat-3/build/Linux-x86_64-GCC
	$(MAKE) -C $(TF_BUILD)/berkeley-testfloat-3/build/Linux-x86_64-GCC testfloat_gen

testfloat: $(TF_GEN)
	@status=0; for fmt in $(TF_FMTS); do for op in $(TF_OPS); do for m in $(TF_MODES); do \
	  case $$m in rne) r=0 g=-rnear_even;; rtz) r=1 g=-rminMag;; rdn) r=2 g=-rmin;; \
	    rup) r=3 g=-rmax;; rmm) r=4 g=-rnear_maxMag;; *) echo "unknown mode $$m"; exit 1;; esac; \
	  $(TF_GEN) -level $(TF_LEVEL) $$g $${fmt}_$$op 2>/dev/null $(if $(TF_N),| head -n $(TF_N)) > vectors.tv; \
	  $(MAKE) --no-print-directory clean; \
	  $(MAKE) --no-print-directory run TESTFLOAT=1 TF_OP=$$op TF_RND=$$r TF_FMT=$$fmt > testfloat_$${fmt}_$${op}_$$m.rpt 2>&1; \
	  [ -f fails.tv ] && mv fails.tv fails_$${fmt}_$${op}_$$m.tv; \
	  echo "$(CORE) $${fmt}_$$op $$m: $$(grep -h 'TESTFLOAT' testfloat_$${fmt}_$${op}_$$m.rpt | tail -1)"; \
	  grep -Eq 'TESTFLOAT vectors=[1-9][0-9]* fails=0$$' testfloat_$${fmt}_$${op}_$$m.rpt || status=1; \
	done; done; done; rm -f vectors.tv; $(MAKE) --no-print-directory clean; exit $$status

testfloat-clean:
	@rm -f vectors.tv fails.tv fails_*.tv testfloat_*.rpt sim_config.vh

.PHONY: testfloat testfloat-clean
