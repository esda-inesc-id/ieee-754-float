VSRC+=$(FMAC_DIR)/hw/src/fmac.v \
$(FMAC_DIR)/hw/src/fmac_core.v \
$(filter-out $(LIB_SRC_DIR)/norm.v,$(LIB_VSRC))

TF_OPS=mul mulAdd
# the full f32_mulAdd level has millions of vectors
TF_N?=200000
