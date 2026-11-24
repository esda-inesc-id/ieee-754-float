CORE_LIST=fadd fmul fdiv fmac fpu
CORE?=fpu
ifeq ($(filter $(CORE),$(CORE_LIST)),)
$(error CORE must be one of: $(CORE_LIST))
endif

# PATHS
FPU_SW_DIR=$(FPU_DIR)/sw_model
REMOTE_ROOT_DIR?=sandbox/ieee-754-float

# SIMULATION: Xcelium runs on CADENCE_SERVER when it is set; an empty server runs locally
SIMULATOR_LIST=icarus xezim xsim xcelium
SIMULATOR?=icarus
ifeq ($(SIMULATOR),xcelium)
SIM_SERVER?=$(CADENCE_SERVER)
SIM_USER?=$(CADENCE_USER)
SIM_SSH_FLAGS?=$(CADENCE_SSH_FLAGS)
SIM_SCP_FLAGS?=$(CADENCE_SCP_FLAGS)
SIM_SYNC_FLAGS?=$(CADENCE_SYNC_FLAGS)
SIM_ENV?=$(CADENCE_ENV)
endif
SIM_DIR?=$(CORE)/hw/sim

# FPGA: Vivado runs on VIVADO_SERVER when it is set; an empty server runs locally
FPGA_SERVER=$(VIVADO_SERVER)
FPGA_USER=$(VIVADO_USER)
FPGA_SSH_FLAGS=$(VIVADO_SSH_FLAGS)
FPGA_SCP_FLAGS=$(VIVADO_SCP_FLAGS)
FPGA_SYNC_FLAGS=$(VIVADO_SYNC_FLAGS)
# VIVADO_ENV: script sourced before vivado; VIVADO_LOCK: one vivado per machine
VIVADO_ENV?=
VIVADO_LOCK?=/tmp/iob_vivado.lock
export VIVADO_ENV VIVADO_LOCK
FPGA_FAMILY?=XCKU
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
