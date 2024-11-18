#
# TOP MAKEFILE
#

FPU_DIR:=.
include core.mk

#
# SIMULATE
#

sim:
ifeq ($(SIM_SERVER), localhost)
	make -C $(SIM_DIR) run SIMULATOR=$(SIMULATOR)
else
	ssh $(SIM_USER)@$(SIM_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	make -C $(SIM_DIR) clean
	rsync -avz --delete --exclude .git $(FPU_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(SIM_USER)@$(SIM_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(SIM_DIR) run SIMULATOR=$(SIMULATOR) TOP_MODULE=$(TOP_MODULE) FLOPOCO=$(FLOPOCO) VCD=$(VCD) SIM_SERVER=localhost'
ifeq ($(VCD),1)
	scp $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)/$(SIM_DIR)/*.vcd $(SIM_DIR)
endif
endif

sim-waves:
	gtkwave $(SIM_DIR)/*.vcd &

sim-clean:
	make -C $(SIM_DIR) clean
ifneq ($(SIM_SERVER), localhost)
	rsync -avz --delete --exclude .git $(FPU_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(SIM_USER)@$(SIM_SERVER) "if [ -d $(REMOTE_ROOT_DIR) ]; then cd $(REMOTE_ROOT_DIR); make -C $(SIM_DIR) clean; fi"
endif

sim-clean-all:
	$(foreach s, $(SIMULATOR_LIST), make sim-clean SIMULATOR=$s;)

#
# FPGA COMPILE
#

fpga:
ifeq ($(FPGA_SERVER), localhost)
	make -C $(FPGA_DIR) run DATA_W=$(DATA_W)
else
	ssh $(FPGA_USER)@$(FPGA_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(FPU_DIR) $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(FPGA_USER)@$(FPGA_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(FPGA_DIR) run FPGA_FAMILY=$(FPGA_FAMILY) TOP_MODULE=$(TOP_MODULE) FPGA_SERVER=localhost'
	mkdir -p $(FPGA_DIR)/$(FPGA_FAMILY)
	scp $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)/$(FPGA_DIR)/$(FPGA_FAMILY)/$(FPGA_LOG) $(FPGA_DIR)/$(FPGA_FAMILY)
endif

fpga-clean:
	make -C $(FPGA_DIR) clean
ifneq ($(FPGA_SERVER), localhost)
	rsync -avz --delete --exclude .git $(FPU_DIR) $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(FPGA_USER)@$(FPGA_SERVER) "if [ -d $(REMOTE_ROOT_DIR) ]; then cd $(REMOTE_ROOT_DIR); make -C $(FPGA_DIR) clean; fi"
endif

fpga-clean-all:
	$(foreach f, $(FPGA_FAMILY_LIST), make fpga-clean FPGA_FAMILY=$f;)

#
# COMPILE ASIC
#

asic:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(ASIC_DIR) ASIC=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(FPU_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh -Y -C $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) TOP_MODULE=$(TOP_MODULE) ASIC=1'
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.log $(ASIC_DIR)/synth
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.txt $(ASIC_DIR)/synth
endif

asic-synth:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(ASIC_DIR) synth ASIC=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(FPU_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh -Y -C $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) TOP_MODULE=$(TOP_MODULE) synth ASIC=1'
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.log $(ASIC_DIR)/synth
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.txt $(ASIC_DIR)/synth
endif

asic-sim-synth:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(HW_DIR)/simulation/ncsim run TEST_LOG=$(TEST_LOG) SYNTH=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(FPU_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(HW_DIR)/simulation/ncsim run TEST_LOG=$(TEST_LOG) SYNTH=1'
ifeq ($(TEST_LOG),1)
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(HW_DIR)/simulation/ncsim/test.log $(HW_DIR)/simulation/ncsim
endif
endif

asic-clean:
	make -C $(ASIC_DIR) clean
ifneq ($(shell hostname), $(ASIC_SERVER))
	rsync -avz --delete --exclude .git $(FPU_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ -d $(REMOTE_ROOT_DIR) ]; then cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) clean; fi"
endif

asic-clean-all:
	$(foreach n, $(ASIC_NODE_LIST), make asic-clean ASIC_NODE=$n;)


# CLEAN ALL
clean-all: sim-clean-all fpga-clean-all asic-clean-all

.PHONY: sim sim-waves sim-clean sim-clean-all \
	fpga fpga-clean fpga-clean-all \
	asic asic-synth asic-sim-synth asic-clean asic-clean-all \
	clean-all
