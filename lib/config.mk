CORE_LIST=fadd fmul fdiv fmac fpu
CORE?=fpu
ifeq ($(filter $(CORE),$(CORE_LIST)),)
$(error CORE must be one of: $(CORE_LIST))
endif

# PATHS
FPU_SW_DIR=$(FPU_DIR)/sw_model
REMOTE_ROOT_DIR?=sandbox/float

# SIMULATION
SIMULATOR_LIST=icarus xezim xsim xcelium
SIMULATOR?=icarus
ifneq ($(and $(filter xcelium,$(SIMULATOR)),$(CADENCE_SERVER)),)
SIM_SERVER?=$(CADENCE_SERVER)
SIM_USER?=$(CADENCE_USER)
endif
SIM_SERVER?=localhost
SIM_USER?=$(USER)
SIM_DIR?=$(CORE)/hw/sim

# FPGA
FPGA_FAMILY?=XCKU
FPGA_USER?=$(USER)
FPGA_SERVER?=$(if $(shell which vivado 2>/dev/null),localhost,pudim-flan.iobundle.com)
FPGA_PART?=xcku040-fbva676-1-c
FPGA_DIR?=$(FPU_DIR)/$(CORE)/hw/fpga
FPGA_LOG?=vivado.log

# ASIC SYNTHESIS
SYN_DIR?=$(CORE)/hw/syn

# SOURCE DIRECTORIES
LIB_SRC_DIR=$(FPU_DIR)/lib/src
FADD_DIR=$(FPU_DIR)/fadd
FMUL_DIR=$(FPU_DIR)/fmul
FDIV_DIR=$(FPU_DIR)/fdiv
FMAC_DIR=$(FPU_DIR)/fmac
FPU_UNIT_DIR=$(FPU_DIR)/fpu
DIV_SUBSHIFT=$(FDIV_DIR)/hw/src/div_subshift.v

# INCLUDES AND HEADERS
INCLUDE+=$(incdir)$(LIB_SRC_DIR)
VHDR+=$(wildcard $(LIB_SRC_DIR)/*.vh)

# FILES SHARED BY THE UNITS
LIB_VSRC=$(LIB_SRC_DIR)/unpack.v \
$(LIB_SRC_DIR)/cls.v \
$(LIB_SRC_DIR)/norm.v \
$(LIB_SRC_DIR)/round.v \
$(LIB_SRC_DIR)/pack.v

# SOURCES OF THE SELECTED UNIT
include $(FPU_DIR)/$(CORE)/hw/hw.mk
