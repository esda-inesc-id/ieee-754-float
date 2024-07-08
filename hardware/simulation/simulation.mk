include $(FPU_DIR)/hardware/hardware.mk

DEFINE+=$(defmacro)VCD

VSRC+=$(FPU_HW_DIR)/testbench/fpu_tb.v

ifeq ($(TEST),mac)
VSRC=$(FPU_HW_DIR)/src/fp_mac.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/clz.v \
$(FPU_HW_DIR)/src/round.v

VSRC+=$(FPU_HW_DIR)/src/testbench/fp_mac_tb.v
endif
