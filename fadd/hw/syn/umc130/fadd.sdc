create_clock -name "clk" -period 8.2 [get_ports {clk}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]
set_clock_transition 0.1 [get_clocks clk]
