# Genus synthesis of one unit; run from its hw/syn directory
source config.tcl

file mkdir $OUTPUT_DIR

set_db stdout_log genus.log
set_db hdl_error_on_latch true
set_db init_hdl_search_path $INCLUDE

# technology library
source $SYN_LIB/$NODE/genus.setup.tcl

# read and elaborate
read_hdl -v2001 -define [concat ASIC $DEFINE] $VSRC
elaborate $NAME
check_design -unresolved

# constraints
read_sdc -stop_on_error ./$NODE/$NAME.sdc
check_design -all > $OUTPUT_DIR/${NAME}_check_design.rpt

# synthesis
syn_generic
report_timing -lint -verbose > $OUTPUT_DIR/${NAME}_lint_gen_timing.rpt
syn_map
syn_opt

insert_tiehilo_cells -verbose
delete_unloaded_undriven -all *

# reports
report_area > $OUTPUT_DIR/${NAME}_area.rpt
report_gates > $OUTPUT_DIR/${NAME}_gates.rpt
report_clocks > $OUTPUT_DIR/${NAME}_clk.rpt
report_timing -max_paths 30 > $OUTPUT_DIR/${NAME}_timing.rpt
report_power > $OUTPUT_DIR/${NAME}_power.rpt
report_qor > $OUTPUT_DIR/${NAME}_qor.rpt

# netlist
write_hdl -mapped -v2001 > $OUTPUT_DIR/${NAME}_synth.v
quit
