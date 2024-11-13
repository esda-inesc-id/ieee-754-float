include $(FPU_DIR)/core.mk

# Defines
ifeq ($(FPU),)
DEFINE+=$(defmacro)SPECIAL_CASES
endif

# Includes
INCLUDE+=$(incdir)$(FPU_INC_DIR)

# Headers
VHDR+=$(wildcard $(FPU_INC_DIR)/*.vh)

# Sources
VSRC+=$(wildcard $(FPU_HW_DIR)/src/*.v) \
$(DIV_DIR)/hardware/src/div_subshift.v

ifneq ($(FPU),)
VSRC:=$(filter-out $(FPU_HW_DIR)/src/fpu.v,$(VSRC))
endif

ifeq ($(TOP_MODULE),ieee754_add)
VSRC=$(FPU_HW_DIR)/src/ieee754_add.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_add.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/norm.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v
endif

ifeq ($(TOP_MODULE),ieee754_mul)
VSRC=$(FPU_HW_DIR)/src/ieee754_mul.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_mul.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/norm.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v
endif

ifeq ($(TOP_MODULE),ieee754_div)
VSRC=$(FPU_HW_DIR)/src/ieee754_div.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_div.v \
$(DIV_DIR)/hardware/src/div_subshift.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/norm.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v
endif

ifeq ($(TOP_MODULE),ieee754_mac)
VSRC=$(FPU_HW_DIR)/src/ieee754_mac.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_mac.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v
endif

ifeq ($(TOP_MODULE),ieee754_fpu)
VSRC=$(FPU_HW_DIR)/src/ieee754_fpu.v \
$(FPU_HW_DIR)/src/fp_special.v \
$(FPU_HW_DIR)/src/ieee754_unpack.v \
$(FPU_HW_DIR)/src/fp_add.v \
$(FPU_HW_DIR)/src/fp_mul.v \
$(FPU_HW_DIR)/src/fp_div.v \
$(DIV_DIR)/hardware/src/div_subshift.v \
$(FPU_HW_DIR)/src/cls.v \
$(FPU_HW_DIR)/src/norm.v \
$(FPU_HW_DIR)/src/round.v \
$(FPU_HW_DIR)/src/ieee754_pack.v
endif
