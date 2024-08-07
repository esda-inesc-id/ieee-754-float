include $(FPU_DIR)/hardware/hardware.mk

INCLUDE+=$(incdir) $(FPU_HW_DIR)/src/testbench

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

ifeq ($(TEST),mul)
VSRC=$(FPU_HW_DIR)/src/fp_mul.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/clz.v \
$(FPU_HW_DIR)/src/round.v

VSRC+=$(FPU_HW_DIR)/src/testbench/fp_mul_tb.v
endif

ifeq ($(TEST),div)
VSRC=$(FPU_HW_DIR)/src/fp_div.v \
$(DIV_DIR)/hardware/src/div_subshift.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/clz.v \
$(FPU_HW_DIR)/src/round.v

VSRC+=$(FPU_HW_DIR)/src/testbench/fp_div_tb.v
endif

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
