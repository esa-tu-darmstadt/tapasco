namespace eval sfpplus {
  namespace export generate_sfp_cores

  set vlnv "xilinx.com:ip:xxv_ethernet:2.0"

  proc generate_sfp_cores {{args {}}} {
    variable vlnv
    if {[tapasco::is_platform_feature_enabled "SFPPLUS"]} {
      set locations {"X0Y12" "X0Y13" "X0Y14" "X0Y15"}
      set disable_pins {"A12" "A13" "B13" "C13"}
      set rx_pins_p {"D2" "C4" "B2" "A4"}
      set tx_pins_p {"E4" "D6" "B6" "A8"}

      # create hierarchical group
      set group [create_bd_cell -type hier "Network"]
      set instance [current_bd_instance .]
      current_bd_instance $group

      set networkIPs [get_bd_cells -of [get_bd_intf_pins -filter {NAME =~ "*sfp_axis_rx*"} $instance/uArch/target_ip_*/*]]

      if { [llength $networkIPs] > 4 } {
        puts "ZCU102 is limited to four SFP+ ports."
        puts "Got $networkIPs"
        exit
      }

      if { [llength $networkIPs] == 0 } {
        puts "No IP with SFP+ connections found."
        puts "Disable Feature SFPPLUS if SFP+ is not used."
        exit
      }

      puts "Adding location constraints for SFP+ connections"

      set constraints_fn_late "[get_property DIRECTORY [current_project]]/sfpplus_late.xdc"
      set constraints_file_late [open $constraints_fn_late w+]

      set constraints_fn "[get_property DIRECTORY [current_project]]/sfpplus.xdc"
      set constraints_file [open $constraints_fn w+]

      puts $constraints_file {set_property PACKAGE_PIN C8 [get_ports gt_refclk_p]}
      puts $constraints_file {create_clock -period 6.400 -name gt_ref_clk [get_ports gt_refclk_p]}

      create_bd_port -dir I -type clk gt_refclk_n
      set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_n]
      create_bd_port -dir I -type clk gt_refclk_p
      set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_p]

      set_property -dict [list CONFIG.CLKOUT2_USED {true} CONFIG.MMCM_DIVCLK_DIVIDE {1} CONFIG.MMCM_CLKOUT1_DIVIDE {12} CONFIG.NUM_OUT_CLKS {2} CONFIG.CLKOUT2_JITTER {115.831} CONFIG.CLKOUT2_PHASE_ERROR {87.180}] [get_bd_cells $instance/ClockResets/clk_wiz]
      set rst_gen [tapasco::createResetGen "sfprstgen"]
      connect_bd_net [get_bd_pins $instance/ClockResets/clk_wiz/clk_out2] [get_bd_pins $rst_gen/slowest_sync_clk]
      connect_bd_net [get_bd_pins $instance/Host/ps_resetn] [get_bd_pins $rst_gen/ext_reset_in]

      set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells $instance/gp0_out]]
      set num_mi [expr "$num_mi_old + 1"]
      set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells $instance/gp0_out]
      set networkConnect [tapasco::createSmartConnect "networkConnect" 1 [llength $networkIPs]]

      connect_bd_intf_net [get_bd_intf_pins $networkConnect/S00_AXI] [get_bd_intf_pins $instance/gp0_out/[format "M%02d_AXI" $num_mi_old]]
      connect_bd_net [get_bd_pins $networkConnect/aclk] [get_bd_pins $instance/gp0_out/aclk]

      create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 reset_inverter
      set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not}] [get_bd_cells reset_inverter]
      connect_bd_net [get_bd_pins $instance/Host/ps_resetn] [get_bd_pins reset_inverter/Op1]

      for {set i 0} {$i < [llength $networkIPs]} {incr i} {
        set ip [lindex $networkIPs $i]
        set location [lindex $locations $i]
        puts "Attaching SFP port $i @ location $location to IP $ip"
        create_bd_cell -type ip -vlnv ${vlnv} sfpmac_$i
        set_property -dict [list CONFIG.GT_GROUP_SELECT {Quad_X1Y3} CONFIG.CORE {Ethernet MAC+PCS/PMA} CONFIG.BASE_R_KR {BASE-R} CONFIG.DATA_PATH_INTERFACE {AXI Stream} CONFIG.INCLUDE_USER_FIFO {1}] [get_bd_cells sfpmac_$i]

        connect_bd_intf_net [get_bd_intf_pins $ip/sfp_axis_tx] [get_bd_intf_pins sfpmac_$i/axis_tx_0]
        connect_bd_intf_net [get_bd_intf_pins $ip/sfp_axis_rx] [get_bd_intf_pins sfpmac_$i/axis_rx_0]

        connect_bd_net [get_bd_pins sfpmac_$i/rx_clk_out_0] [get_bd_pins sfpmac_$i/rx_core_clk_0]

        disconnect_bd_net /uArch/design_aclk_1 [get_bd_pins $ip/tx_clk_in]
        disconnect_bd_net /uArch/design_aclk_1 [get_bd_pins $ip/rx_clk_in]
        connect_bd_net [get_bd_pins sfpmac_$i/tx_clk_out_0] [get_bd_pins $ip/tx_clk_in]
        connect_bd_net [get_bd_pins sfpmac_$i/rx_clk_out_0] [get_bd_pins $ip/rx_clk_in]

        set rst_gen_rx [tapasco::createResetGen [format "rst_rx_%d" $i]]
        connect_bd_net [get_bd_pins sfpmac_$i/rx_clk_out_0] [get_bd_pins $rst_gen_rx/slowest_sync_clk]
        connect_bd_net [get_bd_pins sfpmac_$i/user_rx_reset_0] [get_bd_pins $rst_gen_rx/ext_reset_in]

        set rst_gen_tx [tapasco::createResetGen [format "rst_tx_%d" $i]]
        connect_bd_net [get_bd_pins sfpmac_$i/tx_clk_out_0] [get_bd_pins $rst_gen_tx/slowest_sync_clk]
        connect_bd_net [get_bd_pins sfpmac_$i/user_tx_reset_0] [get_bd_pins $rst_gen_tx/ext_reset_in]

        set rst_gen_paths [tapasco::createResetGen [format "data_rst_gen_%d" $i]]
        connect_bd_net [get_bd_pins sfpmac_$i/rx_clk_out_0] [get_bd_pins $rst_gen_paths/slowest_sync_clk]
        connect_bd_net [get_bd_pins $instance/Host/ps_resetn] [get_bd_pins $rst_gen_paths/ext_reset_in]

        disconnect_bd_net /uArch/design_peripheral_aresetn_1 [get_bd_pins $ip/tx_rst_n_in]
        disconnect_bd_net /uArch/design_peripheral_aresetn_1 [get_bd_pins $ip/rx_rst_n_in]
        connect_bd_net [get_bd_pins $rst_gen_tx/peripheral_aresetn] [get_bd_pins $ip/tx_rst_n_in]
        connect_bd_net [get_bd_pins $rst_gen_rx/peripheral_aresetn] [get_bd_pins $ip/rx_rst_n_in]

        connect_bd_net [get_bd_pins sfpmac_$i/gt_refclk_n] [get_bd_ports /gt_refclk_n]
        connect_bd_net [get_bd_pins sfpmac_$i/gt_refclk_p] [get_bd_ports /gt_refclk_p]

        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $disable_pins $i] sfp_tx_dis_$i]
        puts $constraints_file [format {set_property IOSTANDARD LVCMOS33 [get_ports %s]} sfp_tx_dis_$i]

        puts $constraints_file_late {#CR 965826}
        puts $constraints_file_late {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -datapath_only 6.40}
        puts $constraints_file_late {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -datapath_only 6.40}
        puts $constraints_file_late [format {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -to [get_clocks -of_object [get_nets system_i/Network/sfpmac_%d/dclk]] -datapath_only 6.40} $i]
        puts $constraints_file_late [format {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -to [get_clocks -of_object [get_nets system_i/Network/sfpmac_%d/dclk]] -datapath_only 6.40} $i]
        puts $constraints_file_late [format {set_max_delay -from [get_clocks -of_object [get_nets system_i/Network/sfpmac_%d/dclk]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -datapath_only 10.000} $i]
        puts $constraints_file_late [format {set_max_delay -from [get_clocks -of_object [get_nets system_i/Network/sfpmac_%d/dclk]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -datapath_only 10.000} $i]

        create_bd_port -dir O sfp_tx_dis_$i
        connect_bd_net [get_bd_pins $ip/sfp_enable_tx] [get_bd_ports /sfp_tx_dis_$i]

        create_bd_port -dir I -from 0 -to 0 [format "get_rx_gt_port_%d_n" $i]
        connect_bd_net [get_bd_pins sfpmac_$i/gt_rxn_in] [get_bd_ports [format "/get_rx_gt_port_%d_n" $i]]
        create_bd_port -dir I -from 0 -to 0 [format "get_rx_gt_port_%d_p" $i]
        connect_bd_net [get_bd_pins sfpmac_$i/gt_rxp_in] [get_bd_ports [format "/get_rx_gt_port_%d_p" $i]]
        create_bd_port -dir O -from 0 -to 0 [format "get_tx_gt_port_%d_n" $i]
        connect_bd_net [get_bd_pins sfpmac_$i/gt_txn_out] [get_bd_ports [format "/get_tx_gt_port_%d_n" $i]]
        create_bd_port -dir O -from 0 -to 0 [format "get_tx_gt_port_%d_p" $i]
        connect_bd_net [get_bd_pins sfpmac_$i/gt_txp_out] [get_bd_ports [format "/get_tx_gt_port_%d_p" $i]]

        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $rx_pins_p $i] [format {get_rx_gt_port_%d_p} $i]]
        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $tx_pins_p $i] [format {get_tx_gt_port_%d_p} $i]]

        connect_bd_net [get_bd_pins sfpmac_$i/dclk] [get_bd_pins $instance/ClockResets/clk_wiz/clk_out2]
        connect_bd_net [get_bd_pins sfpmac_$i/s_axi_aclk_0] [get_bd_pins $instance/ClockResets/host_aclk]

        connect_bd_intf_net [get_bd_intf_pins $networkConnect/[format "M%02d_AXI" $i]] [get_bd_intf_pins sfpmac_$i/s_axi_0]

        connect_bd_net [get_bd_pins sfpmac_$i/s_axi_aresetn_0] [get_bd_pins $instance/ClockResets/host_peripheral_aresetn]
        connect_bd_net [get_bd_pins sfpmac_$i/sys_reset] [get_bd_pins $rst_gen/peripheral_reset]
        connect_bd_net [get_bd_pins sfpmac_$i/rx_reset_0] [get_bd_pins $rst_gen_paths/peripheral_reset]
        connect_bd_net [get_bd_pins sfpmac_$i/tx_reset_0] [get_bd_pins $rst_gen_paths/peripheral_reset]

        connect_bd_net [get_bd_pins sfpmac_$i/gtwiz_reset_tx_datapath_0] [get_bd_pins reset_inverter/Res]
        connect_bd_net [get_bd_pins sfpmac_$i/gtwiz_reset_rx_datapath_0] [get_bd_pins reset_inverter/Res]
      }

      close $constraints_file
      read_xdc $constraints_fn
      set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]

      close $constraints_file_late
      read_xdc $constraints_fn_late
      set_property PROCESSING_ORDER LATE [get_files $constraints_fn_late]

      create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.0 system_ila_0
      set_property -dict [list CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} CONFIG.C_BRAM_CNT {11.5} CONFIG.C_NUM_MONITOR_SLOTS {2} CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:display_xxv_ethernet:statistics_ports:2.0}] [get_bd_cells system_ila_0]
      connect_bd_intf_net [get_bd_intf_pins system_ila_0/SLOT_0_AXIS] [get_bd_intf_pins sfpmac_0/axis_tx_0]
      connect_bd_net [get_bd_pins system_ila_0/clk] [get_bd_pins sfpmac_0/tx_clk_out_0]
      connect_bd_intf_net [get_bd_intf_pins system_ila_0/SLOT_1_STATISTICS_PORTS] [get_bd_intf_pins sfpmac_0/stat_tx_0]

      create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.0 system_ila_1
      set_property -dict [list CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} CONFIG.C_BRAM_CNT {11.5} CONFIG.C_NUM_MONITOR_SLOTS {2} CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:display_xxv_ethernet:statistics_ports:2.0}] [get_bd_cells system_ila_1]
      connect_bd_intf_net [get_bd_intf_pins system_ila_1/SLOT_0_AXIS] [get_bd_intf_pins sfpmac_0/axis_rx_0]
      connect_bd_net [get_bd_pins system_ila_1/clk] [get_bd_pins sfpmac_0/rx_clk_out_0]
      connect_bd_intf_net [get_bd_intf_pins system_ila_1/SLOT_1_STATISTICS_PORTS] [get_bd_intf_pins sfpmac_0/stat_rx_0]

      current_bd_instance $instance
    }
    return {}
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_platform_feature_enabled "SFPPLUS"]} {

      set networkIPs [get_bd_cells -of [get_bd_intf_pins -filter {NAME =~ "*sfp_axis_rx*"} uArch/target_ip_*/*]]

      set host_addr_space [get_bd_addr_space "/Host/zynqmp/Data"]
      set offset 0x00A0010000

      for {set i 0} {$i < [llength $networkIPs]} {incr i} {
        set addr_space [get_bd_addr_segs [format "Network/sfpmac_%d/s_axi_0/Reg" $i]]
        create_bd_addr_seg -range 64K -offset $offset $host_addr_space $addr_space "Network_$i"
        incr offset 0x10000
      }
    }
    return {}
  }
}

tapasco::register_plugin "platform::sfpplus::generate_sfp_cores" "post-bd"
tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"