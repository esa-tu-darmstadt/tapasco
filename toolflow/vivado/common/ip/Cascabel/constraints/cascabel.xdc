##
## set properties to help out clock domain crossing analysis
##

set design_clk [get_clocks -of_objects [get_ports -scoped_to_current_instance CLK_design_clk]]
set host_clk [get_clocks -of_object [get_ports -scoped_to_current_instance CLK]]
set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance CLK_design_clk] -flat -endpoints_only] {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance CLK] -flat -only_cells] {IS_SEQUENTIAL && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $design_clk]
set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance CLK] -flat -endpoints_only] {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance CLK_design_clk] -flat -only_cells] {IS_SEQUENTIAL && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $host_clk]


