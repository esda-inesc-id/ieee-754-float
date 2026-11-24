VSRC+=$(FPU_UNIT_DIR)/hw/src/fpu.v \
$(FADD_DIR)/hw/src/add.v \
$(FMUL_DIR)/hw/src/mul.v \
$(FDIV_DIR)/hw/src/div.v \
$(DIV_SUBSHIFT) \
$(LIB_VSRC)

TF_OPS=add sub mul div
