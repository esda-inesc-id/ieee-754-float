include $(FPU_DIR)/lib/config.mk

INCLUDE+=$(incdir)$(FMAC_DIR)/hw/sim/src

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

ifeq ($(STREAMS),1)
TB_TOP=fmac_streams_tb
VSRC+=$(FMAC_DIR)/hw/sim/src/fmac_streams_tb.v
else ifeq ($(FPU_MIX),1)
TB_TOP=fpu_mix_tb
VSRC+=$(FPU_UNIT_DIR)/hw/sim/src/fpu_mix_tb.v
else ifeq ($(TESTFLOAT),1)
TB_TOP=testfloat_tb
VSRC+=$(FPU_DIR)/lib/sim/src/testfloat_tb.v
DEFINE+=$(defmacro)TF_DUT=$(CORE)
TF_RND?=0
DEFINE+=$(defmacro)TF_RND=$(TF_RND)
# divisions are iterative: each one first restarts a dummy division
ifeq ($(TF_OP),div)
DEFINE+=$(defmacro)TF_RESTART
endif
TF_FMT?=f32
TF_DATA_W_f16=16
TF_EXP_W_f16=5
TF_DATA_W_f32=32
TF_EXP_W_f32=8
TF_DATA_W_f64=64
TF_EXP_W_f64=11
DEFINE+=$(defmacro)TF_DATA_W=$(TF_DATA_W_$(TF_FMT)) $(defmacro)TF_EXP_W=$(TF_EXP_W_$(TF_FMT))
ifeq ($(TF_OP),mulAdd)
DEFINE+=$(defmacro)TF_3OP
endif
ifeq ($(CORE),fpu)
TF_FUNCT_add=0
TF_FUNCT_sub=1
TF_FUNCT_mul=2
TF_FUNCT_div=3
DEFINE+=$(defmacro)TF_FPU $(defmacro)TF_FUNCT=$(TF_FUNCT_$(TF_OP))
endif
else
TB_TOP=$(CORE)_tb
VSRC+=$(FPU_DIR)/$(CORE)/hw/sim/src/$(CORE)_tb.v
endif
