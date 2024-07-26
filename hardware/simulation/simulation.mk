include $(FPU_DIR)/hardware/hardware.mk

DEFINE+=$(defmacro)VCD

VSRC+=$(FPU_HW_DIR)/testbench/fpu_tb.v

ifeq ($(TEST),mac)
VSRC=$(FPU_HW_DIR)/src/fp_mac.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/round.v

VSRC+=$(FPU_HW_DIR)/src/testbench/fp_mac_tb.v
endif

ifeq ($(TEST),add)
VSRC=$(FPU_HW_DIR)/src/fp_add.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/round.v

VSRC+=$(FPU_HW_DIR)/src/testbench/fp_add_tb.v
endif

ifeq ($(TEST),div)
VSRC=$(FPU_HW_DIR)/src/fp_div.v \
$(DIV_DIR)/hardware/src/div_subshift.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/clz.v \
$(FPU_HW_DIR)/src/round.v

VSRC+=$(FPU_HW_DIR)/src/testbench/fp_div_tb.v
endif
