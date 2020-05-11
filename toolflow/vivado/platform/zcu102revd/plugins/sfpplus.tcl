# Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
#
# This file is part of TaPaSCo
# (see https://github.com/esa-tu-darmstadt/tapasco).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#


namespace eval sfpplus {
  namespace export generate_sfp_cores

  set vlnv_2016_4 "xilinx.com:ip:xxv_ethernet:2.0"
  set vlnv_2017_2 "xilinx.com:ip:xxv_ethernet:2.2"

  proc generate_sfp_cores {{args {}}} {
    variable vlnv_2016_4
    variable vlnv_2017_2
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {
      set locations {"X0Y12" "X0Y13" "X0Y14" "X0Y15"}
      set disable_pins {"A12" "A13" "B13" "C13"}
      set rx_pins_p {"D2" "C4" "B2" "A4"}
      set tx_pins_p {"E4" "D6" "B6" "A8"}

      set version [version -short]
      if {$version == "2017.2"} {
        set vlnv $vlnv_2017_2
        set mactype "Ethernet MAC+PCS/PMA 64-bit"
      } elseif {$version == "2016.4"} {
        set vlnv $vlnv_2016_4
        set mactype "Ethernet MAC+PCS/PMA"
      } else {
        puts [format "Vivado %s not supported for SFP+" $version]
        exit 1
      }

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

      create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_refclk
      set_property CONFIG.FREQ_HZ 156250000 [get_bd_intf_ports /gt_refclk]

      puts $constraints_file {set_property PACKAGE_PIN C8 [get_ports gt_refclk_clk_p]}
      puts $constraints_file {create_clock -period 6.400 -name gt_ref_clk [get_ports gt_refclk_clk_p]}

      create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 gt_serial_port

      set num_clocks_old [get_property CONFIG.NUM_OUT_CLKS [get_bd_cells $instance/ClockResets/clk_wiz]]
      set num_clocks [expr "$num_clocks_old + 1"]
      set_property -dict [list CONFIG.CLKOUT${num_clocks}_USED {true} CONFIG.CLKOUT${num_clocks}_REQUESTED_OUT_FREQ 100] [get_bd_cells $instance/ClockResets/clk_wiz]
      set slow_clk [get_bd_pins $instance/ClockResets/clk_wiz/clk_out${num_clocks}]

      set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells $instance/gp0_out]]
      set num_mi [expr "$num_mi_old + 1"]
      set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells $instance/gp0_out]

      set networkConnect [tapasco::createSmartConnect "networkConnect" 1 [llength $networkIPs] 0 [expr "[llength $networkIPs] + 1"]]
      connect_bd_intf_net [get_bd_intf_pins $networkConnect/S00_AXI] [get_bd_intf_pins $instance/gp0_out/[format "M%02d_AXI" $num_mi_old]]
      connect_bd_net [get_bd_pins $networkConnect/aclk] [get_bd_pins $instance/gp0_out/aclk]

      set reset_inverter [tapasco::createLogicInverter "reset_inverter"]
      connect_bd_net [get_bd_pins $instance/Host/ps_resetn] [get_bd_pins $reset_inverter/Op1]

      create_bd_cell -type ip -vlnv ${vlnv} sfpmac
      set_property -dict [list CONFIG.NUM_OF_CORES [llength $networkIPs] CONFIG.GT_GROUP_SELECT {Quad_X1Y3} CONFIG.CORE $mactype CONFIG.BASE_R_KR {BASE-R} CONFIG.DATA_PATH_INTERFACE {AXI Stream} CONFIG.INCLUDE_USER_FIFO {0}] [get_bd_cells sfpmac]

      puts $constraints_file_late {#CR 965826}
      puts $constraints_file_late {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -datapath_only 6.40}
      puts $constraints_file_late {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -datapath_only 6.40}
      puts $constraints_file_late {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -to [get_clocks -of_object [get_nets system_i/Network/sfpmac/dclk]] -datapath_only 6.40}
      puts $constraints_file_late {set_max_delay -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -to [get_clocks -of_object [get_nets system_i/Network/sfpmac/dclk]] -datapath_only 6.40}
      puts $constraints_file_late {set_max_delay -from [get_clocks -of_object [get_nets system_i/Network/sfpmac/dclk]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/TXOUTCLK}]] -datapath_only 10.000}
      puts $constraints_file_late {set_max_delay -from [get_clocks -of_object [get_nets system_i/Network/sfpmac/dclk]] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */channel_inst/*_CHANNEL_PRIM_INST/RXOUTCLK}]] -datapath_only 10.000}

      connect_bd_net [get_bd_pins sfpmac/dclk] $slow_clk
      connect_bd_net [get_bd_pins sfpmac/sys_reset] [get_bd_pins $reset_inverter/Res]

      connect_bd_intf_net [get_bd_intf_ports /gt_refclk] [get_bd_intf_pins sfpmac/gt_ref_clk]
      connect_bd_intf_net [get_bd_intf_ports /gt_serial_port] [get_bd_intf_pins sfpmac/gt_serial_port]

      for {set i 0} {$i < [llength $networkIPs]} {incr i} {
        set ip [lindex $networkIPs $i]
        set location [lindex $locations $i]
        puts "Attaching SFP port $i @ location $location to IP $ip"

        connect_bd_intf_net [get_bd_intf_pins $ip/sfp_axis_tx] [get_bd_intf_pins sfpmac/axis_tx_${i}]
        connect_bd_intf_net [get_bd_intf_pins $ip/sfp_axis_rx] [get_bd_intf_pins sfpmac/axis_rx_${i}]

        connect_bd_net [get_bd_pins sfpmac/tx_clk_out_${i}] [get_bd_pins sfpmac/rx_core_clk_${i}]

        disconnect_bd_net /uArch/design_aclk_1 [get_bd_pins $ip/tx_clk_in]
        disconnect_bd_net /uArch/design_aclk_1 [get_bd_pins $ip/rx_clk_in]
        connect_bd_net [get_bd_pins sfpmac/tx_clk_out_${i}] [get_bd_pins $ip/tx_clk_in]
        connect_bd_net [get_bd_pins sfpmac/rx_clk_out_${i}] [get_bd_pins $ip/rx_clk_in]

        set rx_inv [tapasco::createLogicInverter [format "rst_rx_inverter_%d" $i]]
        connect_bd_net [get_bd_pins sfpmac/user_rx_reset_${i}] [get_bd_pins $rx_inv/Op1]
        disconnect_bd_net /uArch/design_peripheral_aresetn_1 [get_bd_pins $ip/rx_rst_n_in]
        connect_bd_net [get_bd_pins $rx_inv/Res] [get_bd_pins $ip/rx_rst_n_in]

        set tx_inv [tapasco::createLogicInverter [format "rst_tx_inverter_%d" $i]]
        connect_bd_net [get_bd_pins sfpmac/user_tx_reset_${i}] [get_bd_pins $tx_inv/Op1]
        connect_bd_net [get_bd_pins $tx_inv/Res] [get_bd_pins sfpmac/s_axi_aresetn_${i}]
        disconnect_bd_net /uArch/design_peripheral_aresetn_1 [get_bd_pins $ip/tx_rst_n_in]
        connect_bd_net [get_bd_pins $tx_inv/Res] [get_bd_pins $ip/tx_rst_n_in]

        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $disable_pins $i] sfp_tx_dis_$i]
        puts $constraints_file [format {set_property IOSTANDARD LVCMOS33 [get_ports %s]} sfp_tx_dis_$i]

        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $rx_pins_p $i] [format {gt_serial_port_grx_p[%d]} $i]]
        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $tx_pins_p $i] [format {gt_serial_port_gtx_p[%d]} $i]]

        create_bd_port -dir O sfp_tx_dis_$i
        connect_bd_net [get_bd_pins $ip/sfp_enable_tx] [get_bd_ports /sfp_tx_dis_$i]

        connect_bd_net [get_bd_pins sfpmac/s_axi_aclk_${i}] [get_bd_pins sfpmac/tx_clk_out_${i}]

        connect_bd_net [get_bd_pins $networkConnect/aclk[expr "$i + 1"]] [get_bd_pins sfpmac/tx_clk_out_${i}]

        connect_bd_intf_net [get_bd_intf_pins $networkConnect/[format "M%02d_AXI" $i]] [get_bd_intf_pins sfpmac/s_axi_${i}]

        connect_bd_net [get_bd_pins sfpmac/rx_reset_${i}] [get_bd_pins $reset_inverter/Res]
        connect_bd_net [get_bd_pins sfpmac/tx_reset_${i}] [get_bd_pins $reset_inverter/Res]

        connect_bd_net [get_bd_pins sfpmac/gtwiz_reset_tx_datapath_${i}] [get_bd_pins $reset_inverter/Res]
        connect_bd_net [get_bd_pins sfpmac/gtwiz_reset_rx_datapath_${i}] [get_bd_pins $reset_inverter/Res]
      }

      close $constraints_file
      read_xdc $constraints_fn
      set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]

      close $constraints_file_late
      read_xdc $constraints_fn_late
      set_property PROCESSING_ORDER LATE [get_files $constraints_fn_late]

      current_bd_instance $instance
    }
    return {}
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {

      set networkIPs [get_bd_cells -of [get_bd_intf_pins -filter {NAME =~ "*sfp_axis_rx*"} uArch/target_ip_*/*]]

      set host_addr_space [get_bd_addr_space "/Host/zynqmp/Data"]
      set offset 0x00A0010000

      for {set i 0} {$i < [llength $networkIPs]} {incr i} {
        set addr_space [get_bd_addr_segs [format "Network/sfpmac/s_axi_%d/Reg" $i]]
        create_bd_addr_seg -range 64K -offset $offset $host_addr_space $addr_space "Network_$i"
        incr offset 0x10000
      }
    }
    return {}
  }
}

tapasco::register_plugin "platform::sfpplus::generate_sfp_cores" "post-bd"
tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"