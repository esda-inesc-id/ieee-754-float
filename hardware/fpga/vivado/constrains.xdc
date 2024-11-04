# Clock
#create_clock -period 10.000 [get_ports clk]
create_clock -name "clk" -period 10.000 [get_ports {clk}]

# Reset
set_false_path -from [get_ports {rst}] -to [get_clocks {*}]

set_property CFGBVS VCCO [current_design]

set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk]
