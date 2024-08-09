include $(FPU_DIR)/hardware/hardware.mk

INCLUDE+=$(incdir) $(FPU_HW_DIR)/src/testbench

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

VSRC+=$(FPU_HW_DIR)/testbench/fpu_tb.v

ifeq ($(TEST),ieee754_add)
VSRC=$(FPU_HW_DIR)/src/ieee754_add.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_add.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/norm.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v

VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_add_tb.v
endif

ifeq ($(TEST),ieee754_mul)
VSRC=$(FPU_HW_DIR)/src/ieee754_mul.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_mul.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/norm.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v

VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_mul_tb.v
endif

ifeq ($(TEST),ieee754_div)
VSRC=$(FPU_HW_DIR)/src/ieee754_div.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_div.v \
$(DIV_DIR)/hardware/src/div_subshift.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/norm.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v

VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_div_tb.v
endif

ifeq ($(TEST),ieee754_mac)
VSRC=$(FPU_HW_DIR)/src/ieee754_mac.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_mac.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v

VSRC+=$(FPU_HW_DIR)/src/testbench/ieee754_mac_tb.v
endif
