SYN_SERVER=$(CADENCE_SERVER)
SYN_USER=$(CADENCE_USER)
SYN_SSH_FLAGS=$(CADENCE_SSH_FLAGS)
SYN_SCP_FLAGS=$(CADENCE_SCP_FLAGS)
SYN_SYNC_FLAGS=$(CADENCE_SYNC_FLAGS)

synth: $(VHDR) $(VSRC) config.tcl
	genus -batch -files $(SYN_LIB)/genus/build.tcl -wait 10000

config.tcl:
	@echo "set NODE $(NODE)" > $@
	@echo "set NAME $(NAME)" >> $@
	@echo "set SYN_LIB $(SYN_LIB)" >> $@
	@echo "set OUTPUT_DIR $(OUTPUT_DIR)" >> $@
	@echo "set INCLUDE [list $(INCLUDE)]" >> $@
	@echo "set DEFINE [list $(DEFINE)]" >> $@
	@echo "set VSRC [glob $(VSRC)]" >> $@
