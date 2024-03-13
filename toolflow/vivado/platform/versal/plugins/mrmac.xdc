set mrmac_userclk [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */mrmac_port*_cell/user_clk_wiz/inst/clock_primitive_inst/BUFG_clkout1_inst/O}]]
set mrmac_userclk_period [get_property PERIOD [get_clocks clkout1_primitive]]

set mrmac_tx_clk [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */mrmac_port*_cell/mbufg_gt_0/U0/USE_MBUFG_GT_SYNC.GEN_MBUFG_GT[0].MBUFG_GT_U/O1}]]
set mrmac_rx_clk [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */mrmac_port*_cell/mbufg_gt_1/U0/USE_MBUFG_GT_SYNC.GEN_MBUFG_GT[0].MBUFG_GT_U/O1}]]
set mrmac_clk_period 1.552

set dsgn_clk [get_clocks -of_objects [get_pins system_i/clocks_and_resets/design_clk_wiz/inst/clock_primitive_inst/BUFG_clkout1_inst/O]]
set dsgn_clk_period [get_property PERIOD $dsgn_clk]

# 384bit with user clock only
set_max_delay -datapath_only -from $mrmac_userclk -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */mbufg_gt_*/U0/USE_MBUFG_GT*.GEN_MBUFG_GT*.MBUFG_GT_U/O*}]] $mrmac_userclk_period
set_max_delay -from [get_clocks -of_objects [get_pins {system_i/network/mrmac_port_*_cell/mbufg_gt_*/U0/USE_MBUFG_GT_SYNC.GEN_MBUFG_GT[0].MBUFG_GT_U/O1}]] -to $mrmac_userclk $mrmac_userclk_period

# 384bit
set_max_delay -datapath_only -from [get_pins {system_i/network/mrmac_port_*_cell/mrmac_port_*/inst/i_system_mrmac_port_*_versal_gt_reset_controller_0/inst/use_master_reset.system_mrmac_port_*_versal_gt_reset_controller_0_master_reset_synchronizer_gtwiz_reset_all_inst_rx_1/syncstages_ff_reg[2]/C}] -to $mrmac_userclk $mrmac_userclk_period

# 256bit
set_max_delay -datapath_only -from [get_pins {system_i/network/mrmac_port_*_cell/mrmac_port_*/inst/i_system_mrmac_port_*_versal_gt_reset_controller_0/inst/use_master_reset.system_mrmac_port_*_versal_gt_reset_controller_0_master_reset_synchronizer_gtwiz_reset_all_inst_rx_1/syncstages_ff_reg[2]/C}] -to $mrmac_rx_clk $mrmac_clk_period
set_max_delay -datapath_only -from [get_pins {system_i/network/mrmac_port_*_cell/mrmac_port_*/inst/i_system_mrmac_port_*_versal_gt_reset_controller_0/inst/use_master_reset.system_mrmac_port_*_versal_gt_reset_controller_0_master_reset_synchronizer_gtwiz_reset_all_inst_tx_1/syncstages_ff_reg[2]/C}] -to $mrmac_tx_clk $mrmac_clk_period
set_max_delay -datapath_only -from [get_pins {system_i/arch/SFP_port_*_reciever/reciever_sync/s00_couplers/auto_cc/inst/gen_async_conv.axisc_async_clock_converter_0/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/gen_sdpram.xpm_memory_base_inst/gen_wr_a.gen_word_narrow.mem_reg_*/RAM*/CLK}] -to $dsgn_clk $dsgn_clk_period
set_max_delay -datapath_only -from [get_pins {system_i/arch/SFP_port_*_transmitter/transmitter_sync/s00_couplers/auto_cc/inst/gen_async_conv.axisc_async_clock_converter_0/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/gen_sdpram.xpm_memory_base_inst/gen_wr_a.gen_word_narrow.mem_reg_*/RAM*/CLK}] -to $mrmac_tx_clk $mrmac_clk_period
