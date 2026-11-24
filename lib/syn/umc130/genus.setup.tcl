# the UMC 130 nm (Faraday) library directory, from the environment
if {![info exists ::env(UMC130_DIR)]} {
  puts "ERROR: UMC130_DIR is not set: export it as the directory of the UMC 130 nm (Faraday) libraries"
  exit 1
}
set LIBDIR $::env(UMC130_DIR)

set_db lib_search_path [list $LIBDIR/LL/fsc0l_d/2009Q2v3.0/GENERIC_CORE/FrontEnd/synopsys]

set_db library [list fsc0l_d_generic_core_ss1p08v125c.lib]

