include $(FPU_DIR)/hardware/hardware.mk

INCLUDE+=$(incdir) $(FPU_HW_DIR)/src/testbench

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

#VSRC+=$(FPU_HW_DIR)/testbench/fpu_tb.v

ifeq ($(TOP_MODULE),ieee754_add)
VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_add_tb.v
endif

ifeq ($(TOP_MODULE),ieee754_mul)
VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_mul_tb.v
endif

ifeq ($(TOP_MODULE),ieee754_div)
VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_div_tb.v
endif

ifeq ($(TOP_MODULE),ieee754_mac)
VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_mac_tb.v
endif

ifeq ($(TOP_MODULE),ieee754_fpu)
VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_fpu_tb.v
endif
