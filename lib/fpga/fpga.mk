FPGA_OBJ?=$(FPGA_FAMILY)/$(CORE).edif
CONSTRAINTS:=$(wildcard *.xdc)

include $(FPU_DIR)/lib/config.mk

FPGA_VSRC=$(addprefix ../, $(VSRC) )
FPGA_VHDR=$(addprefix ../, $(VHDR) )
FPGA_INCLUDE=$(addprefix ../, $(INCLUDE) )

run: $(FPGA_OBJ)

$(FPGA_OBJ): $(CONSTRAINTS) $(VSRC) $(VHDR)
	mkdir -p $(FPGA_FAMILY)
	cd $(FPGA_FAMILY); $(abspath $(FPU_DIR)/lib/fpga/build.sh) "$(CORE)" "$(FPGA_PART)" "$(FPGA_VSRC)" "$(FPGA_INCLUDE)" "$(DEFINE)"

clean:
	 rm -rf $(FPGA_FAMILY) *.v *.vh

.PHONY: run clean
