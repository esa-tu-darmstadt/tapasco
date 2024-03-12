set mrmac_userclk [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */mrmac_port*_cell/user_clk_wiz/inst/clock_primitive_inst/BUFG_clkout1_inst/O}]]
set mrmac_userclk_period [get_property PERIOD [get_clocks clkout1_primitive]]

set mrmac_clk [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */mrmac_port*_cell/mbufg_gt_0/U0/USE_MBUFG_GT_SYNC.GEN_MBUFG_GT[0].MBUFG_GT_U/O1}]]
set mrmac_clk_period 1.552

# 384bit with user clock only
set_max_delay -datapath_only -from $mrmac_userclk -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */mbufg_gt_*/U0/USE_MBUFG_GT*.GEN_MBUFG_GT*.MBUFG_GT_U/O*}]] $mrmac_userclk_period
set_max_delay -from [get_clocks -of_objects [get_pins {system_i/network/mrmac_port_*_cell/mbufg_gt_*/U0/USE_MBUFG_GT_SYNC.GEN_MBUFG_GT[0].MBUFG_GT_U/O1}]] -to $mrmac_userclk $mrmac_userclk_period

# 384bit
set_max_delay -datapath_only -from [get_pins {system_i/network/mrmac_port_*_cell/mrmac_port_*/inst/i_system_mrmac_port_*_versal_gt_reset_controller_0/inst/use_master_reset.system_mrmac_port_*_versal_gt_reset_controller_0_master_reset_synchronizer_gtwiz_reset_all_inst_rx_1/syncstages_ff_reg[2]/C}] -to $mrmac_userclk $mrmac_userclk_period

# 256bit
set_max_delay -datapath_only -from [get_pins {system_i/network/mrmac_port_*_cell/mrmac_port_*/inst/i_system_mrmac_port_*_versal_gt_reset_controller_0/inst/use_master_reset.system_mrmac_port_*_versal_gt_reset_controller_0_master_reset_synchronizer_gtwiz_reset_all_inst_rx_1/syncstages_ff_reg[2]/C}] -to $mrmac_clk $mrmac_clk_period
