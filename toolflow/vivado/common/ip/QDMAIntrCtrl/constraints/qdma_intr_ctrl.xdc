##
## set properties to help out clock domain crossing analysis
##

set s_clk [get_clocks -of_objects [get_ports -scoped_to_current_instance S_AXI_aclk]]
set m_clk [get_clocks -of_object [get_ports -scoped_to_current_instance design_clk]]
set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance S_AXI_aclk] -flat -endpoints_only]          {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance design_clk] -flat -only_cells] {IS_SEQUENTIAL    && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $s_clk]
 set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance design_clk] -flat -endpoints_only]          {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance S_AXI_aclk] -flat -only_cells] {IS_SEQUENTIAL    && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $m_clk]

set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *reset_hold_reg*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *sGEnqPtr*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dGDeqPtr*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *sSyncReg*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dSyncReg*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dEnqPtr*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dEnqToggle*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dDeqToggle*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dNotEmpty*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dLastState*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ design_rst}] -to [filter [get_cells -hier -filter {NAME =~ *dSyncPulse_reg*}] {IS_SEQUENTIAL}]
