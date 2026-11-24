# make <target> [CORE=fadd|fmul|fdiv|fmac|fpu] [SIMULATOR=icarus|xezim|xsim|xcelium]
# CADENCE_SERVER (Xcelium, Genus) and VIVADO_SERVER: empty runs locally
# make run CPROG=<example>|all|ieee754_tests
# make run PYPROG=<program> [ARGS="<arguments>"]

FPU_DIR := .
include lib/config.mk

# Tests and clean cover every core unless CORE is on the command line
CORES = $(if $(filter command line,$(origin CORE)),$(CORE),$(CORE_LIST))

SMOKE_N ?= 1000
SMOKE_STREAMS ?= 300
SMOKE_MIX ?= 2000

MAKE_SUB = make --no-print-directory

# Variables passed on to a remote run
FWD_VARS = CORE VCD TF_N TF_LEVEL STREAM_N MIX_N SMOKE_N SMOKE_STREAMS SMOKE_MIX
FWD = SIMULATOR=$(SIMULATOR) $(foreach v,$(FWD_VARS),$(if $(filter command line,$(origin $(v))),$(v)=$($(v))))

# $(1): SIM or FPGA; $(2): command run in the copy of this directory on $(1)_SERVER
define remote
ssh $($(1)_SSH_FLAGS) $($(1)_USER)@$($(1)_SERVER) 'mkdir -p $(REMOTE_ROOT_DIR)'
rsync $($(1)_SYNC_FLAGS) -az --delete --exclude .git --exclude lib/sim/testfloat-build $(FPU_DIR)/ $($(1)_USER)@$($(1)_SERVER):$(REMOTE_ROOT_DIR)
ssh $($(1)_SSH_FLAGS) $($(1)_USER)@$($(1)_SERVER) 'cd $(REMOTE_ROOT_DIR) && $(if $($(1)_ENV),source $($(1)_ENV) > /dev/null && )$(2)'
endef

help:
	@sed -n '1,4p' Makefile
	@echo "targets: sim sim-waves test test-smoke test-regular test-full fpga-build syn-build"
	@echo "         run sw-test sw-check doc clean"

#
# SIMULATION AND TESTS: the regular tests run only if the smoke tests pass;
# test-full runs every TestFloat vector of the level
#

ifneq ($(SIM_SERVER),)

sim test test-smoke test-regular test-full:
	$(call remote,SIM,make $@ $(FWD) CADENCE_SERVER=)
ifeq ($(VCD),1)
	scp $(SIM_SCP_FLAGS) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)/$(SIM_DIR)/*.vcd $(SIM_DIR)
endif

else

sim:
	$(MAKE_SUB) -C $(SIM_DIR) run

test: test-smoke test-regular

test-full: test-smoke
	@$(MAKE_SUB) test-regular TF_N=

test-smoke:
	@for c in $(CORES); do \
	  $(MAKE_SUB) -C $$c/hw/sim testfloat CORE=$$c TF_N=$(SMOKE_N) || { echo "SMOKE FAILED: $$c"; exit 1; }; \
	done
ifneq ($(filter fmac,$(CORES)),)
	@$(MAKE_SUB) -C fmac/hw/sim streams CORE=fmac STREAM_N=$(SMOKE_STREAMS) || { echo "SMOKE FAILED: fmac streams"; exit 1; }
endif
ifneq ($(filter fpu,$(CORES)),)
	@$(MAKE_SUB) -C fpu/hw/sim mix CORE=fpu MIX_N=$(SMOKE_MIX) || { echo "SMOKE FAILED: fpu mix"; exit 1; }
endif
	@echo "SMOKE PASSED"

test-regular:
	@status=0; \
	for c in $(CORES); do $(MAKE_SUB) -C $$c/hw/sim testfloat CORE=$$c || status=1; done; \
	if [ -n "$(filter fmac,$(CORES))" ]; then $(MAKE_SUB) -C fmac/hw/sim streams CORE=fmac || status=1; fi; \
	if [ -n "$(filter fpu,$(CORES))" ]; then $(MAKE_SUB) -C fpu/hw/sim mix CORE=fpu || status=1; fi; \
	if [ $$status -eq 0 ]; then echo "REGULAR PASSED"; else echo "REGULAR FAILED"; fi; \
	exit $$status

endif

sim-waves:
	gtkwave $(SIM_DIR)/*.vcd &

#
# FPGA: out-of-context place and route
#

fpga-build:
ifeq ($(FPGA_SERVER),)
	$(MAKE_SUB) -C $(FPGA_DIR) run
else
	$(call remote,FPGA,make -C $(FPGA_DIR) run CORE=$(CORE) VIVADO_SERVER=)
	mkdir -p $(FPGA_DIR)/$(FPGA_FAMILY)
	scp $(FPGA_SCP_FLAGS) $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)/$(FPGA_DIR)/$(FPGA_FAMILY)/$(FPGA_LOG) $(FPGA_DIR)/$(FPGA_FAMILY)
endif

#
# ASIC SYNTHESIS
#

syn-build:
	$(MAKE_SUB) -C $(SYN_DIR) build

#
# SOFTWARE MODEL
#

run:
ifeq ($(CPROG)$(PYPROG),)
	$(error set CPROG=<example>|all|ieee754_tests or PYPROG=<program>)
endif
	$(MAKE_SUB) -C $(FPU_SW_DIR) run

sw-test:
	$(MAKE_SUB) -C $(FPU_SW_DIR) test

sw-check:
	$(MAKE_SUB) -C $(FPU_SW_DIR) check

#
# DOCUMENTATION
#

doc:
	$(MAKE_SUB) -C doc

#
# CLEAN: local files only; keeps the user guide PDF
#

clean:
	@for c in $(CORES); do \
	  for s in $(SIMULATOR_LIST); do $(MAKE_SUB) -C $$c/hw/sim clean SIMULATOR=$$s CORE=$$c; done; \
	  $(MAKE_SUB) -C $$c/hw/sim testfloat-clean CORE=$$c; \
	  $(MAKE_SUB) -C $$c/hw/fpga clean CORE=$$c; \
	  $(MAKE_SUB) -C $$c/hw/syn clean CORE=$$c > /dev/null; \
	done
ifneq ($(filter fmac,$(CORES)),)
	@$(MAKE_SUB) -C fmac/hw/sim streams-clean CORE=fmac
endif
ifneq ($(filter fpu,$(CORES)),)
	@$(MAKE_SUB) -C fpu/hw/sim mix-clean CORE=fpu
endif
	@$(MAKE_SUB) -C $(FPU_SW_DIR) clean > /dev/null
	@$(MAKE_SUB) -C doc clean > /dev/null

.PHONY: help sim sim-waves test test-smoke test-regular test-full fpga-build syn-build \
	run sw-test sw-check doc clean
