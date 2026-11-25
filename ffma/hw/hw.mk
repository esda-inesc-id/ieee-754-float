VSRC+=$(FFMA_DIR)/hw/src/ffma.v \
$(FFMA_DIR)/hw/src/ffma_core.v \
$(filter-out $(LIB_SRC_DIR)/norm.v,$(LIB_VSRC))

TF_OPS=mulAdd
# the full f32_mulAdd level has millions of vectors
TF_N?=200000
