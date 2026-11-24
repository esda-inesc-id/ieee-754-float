SHELL:=bash

OUTPUT_DIR=results
SYNTHESIZER?=genus
NODE?=umc130
NAME=$(CORE)

include $(FPU_DIR)/lib/config.mk

SYN_LIB=$(abspath $(FPU_DIR)/lib/syn)
REMOTE_SYN_DIR=$(REMOTE_ROOT_DIR)/$(CORE)/hw/syn

# the node's library directory, from the environment (e.g. UMC130_DIR)
NODE_DIR_VAR:=$(shell echo $(NODE) | tr a-z A-Z)_DIR

include $(SYN_LIB)/$(SYNTHESIZER)/build.mk

build: $(VHDR) $(VSRC)
ifeq ($(SYN_SERVER),)
	$(MAKE) synth
else
	ssh $(SYN_SSH_FLAGS) $(SYN_USER)@$(SYN_SERVER) 'mkdir -p $(REMOTE_ROOT_DIR)'
	rsync $(SYN_SYNC_FLAGS) -avz --force --delete --exclude .git $(FPU_DIR)/ $(SYN_USER)@$(SYN_SERVER):$(REMOTE_ROOT_DIR)
	ssh -t $(SYN_SSH_FLAGS) -Y -C $(SYN_USER)@$(SYN_SERVER) '$(if $($(NODE_DIR_VAR)),export $(NODE_DIR_VAR)=$($(NODE_DIR_VAR)); )make -C $(REMOTE_SYN_DIR) synth CORE=$(CORE) NODE=$(NODE) SYNTHESIZER=$(SYNTHESIZER)'
	scp $(SYN_SCP_FLAGS) $(SYN_USER)@$(SYN_SERVER):$(REMOTE_SYN_DIR)/*.log .
	scp $(SYN_SCP_FLAGS) $(SYN_USER)@$(SYN_SERVER):$(REMOTE_SYN_DIR)/$(OUTPUT_DIR)/*.rpt .
	scp $(SYN_SCP_FLAGS) $(SYN_USER)@$(SYN_SERVER):$(REMOTE_SYN_DIR)/$(OUTPUT_DIR)/*.v .
endif

clean:
	find . -maxdepth 1 -type f -not -name Makefile -delete
	@rm -rf fv results st_part_log

.PHONY: build clean synth config.tcl
