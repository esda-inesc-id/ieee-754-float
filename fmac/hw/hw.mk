VSRC+=$(FMAC_DIR)/hw/src/fmac.v \
$(FMAC_DIR)/hw/src/fmac_core.v \
$(FMAC_DIR)/hw/src/fmac_core1.v \
$(LIB_VSRC)

TF_OPS=mul mulAdd
# the full f32_mulAdd level has millions of vectors
TF_N?=200000
