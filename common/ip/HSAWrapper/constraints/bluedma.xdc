##
## set properties to help out clock domain crossing analysis
##

set s_clk [get_clocks -of_objects [get_ports -scoped_to_current_instance mdma_ddr_axi_aclk]]
set m_clk [get_clocks -of_object [get_ports -scoped_to_current_instance mdma_pcie_axi_aclk]]
set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_ddr_axi_aclk] -flat -endpoints_only]          {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_pcie_axi_aclk] -flat -only_cells] {IS_SEQUENTIAL    && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $s_clk]
 set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_pcie_axi_aclk] -flat -endpoints_only]          {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_ddr_axi_aclk] -flat -only_cells] {IS_SEQUENTIAL    && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $m_clk]

set g_clk [get_clocks -of_objects [get_ports -scoped_to_current_instance s_axi_aclk]]

set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_ddr_axi_aclk] -flat -endpoints_only]          {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance s_axi_aclk] -flat -only_cells] {IS_SEQUENTIAL &&   (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $s_clk]
set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance s_axi_aclk] -flat -endpoints_only]            {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_ddr_axi_aclk] -flat -only_cells] {IS_SEQUENTIAL    && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $g_clk]

set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_pcie_axi_aclk] -flat -endpoints_only]          {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance s_axi_aclk] -flat -only_cells] {IS_SEQUENTIAL &&   (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $m_clk]
set_max_delay -from [filter [all_fanout -from [get_ports -scoped_to_current_instance s_axi_aclk] -flat -endpoints_only]            {IS_LEAF}] -to [filter [all_fanout -from [get_ports -scoped_to_current_instance mdma_pcie_axi_aclk] -flat -only_cells] {IS_SEQUENTIAL    && (NAME !~ *dout_i_reg[*])}] -datapath_only [get_property -min PERIOD $g_clk]

set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *reset_hold_reg*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *sGEnqPtr*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *dGDeqPtr*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *sSyncReg*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *dSyncReg*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *dEnqPtr*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *dEnqToggle*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *dDeqToggle*}] {IS_SEQUENTIAL}]
set_false_path -through [get_ports -scoped_to_current_instance -filter {NAME =~ *_axi_aresetn}] -to [filter [get_cells -hier -filter {NAME =~ *dNotEmpty*}] {IS_SEQUENTIAL}]