namespace eval sfpplus {
  namespace export generate_sfp_cores

  set vlnv_2016_4 "xilinx.com:ip:axi_10g_ethernet:3.1"
  set vlnv_2017_2 "xilinx.com:ip:axi_10g_ethernet:3.1"

  proc generate_sfp_cores {{args {}}} {
    variable vlnv_2016_4
    variable vlnv_2017_2
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {
      set disable_pins {"M18" "B31" "J38" "L21"}
      set tx_fault_pins {"M19" "C26" "E39" "J26"}
      set signal_detect_pins {"N18" "L19" "J37" "H36"}
      set rx_pins_p {"B4" "C2" "D4" "E2"}
      set tx_pins_p {"A6" "B8" "C6" "D8"}
      set locations {"GTHE2_CHANNEL_X1Y39" "GTHE2_CHANNEL_X1Y38" "GTHE2_CHANNEL_X1Y37" "GTHE2_CHANNEL_X1Y36"}

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

      set networkStreams [get_bd_intf_pins -filter {NAME =~ "*sfp_axis_*_rx*"} $instance/uArch/target_ip_*/*]

      set networkIPs [list]

      for {set i 0} {$i < [llength $networkStreams]} {incr i} {
        set stream [lindex $networkStreams $i]
        regexp {/uArch/(.+)/sfp_axis(_.+)_rx} $stream matched ip sfp_name
        puts "Found SFP Port"
        puts [format "IP: %s" $ip]
        puts [format "SFP Name: %s" $sfp_name]
        lappend networkIPs [format "/uArch/%s/sfp_axis%s" $ip $sfp_name]
      }

      if { [llength $networkIPs] > 4 } {
        puts "NetFPGA SUME is limited to four SFP+ ports."
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

      create_bd_port -dir I gt_refclk_clk_p
      create_bd_port -dir I gt_refclk_clk_n
      set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_clk_p]
      set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_clk_n]

      puts $constraints_file {set_property PACKAGE_PIN E10 [get_ports gt_refclk_clk_p]}
      puts $constraints_file {create_clock -period 6.400 -name gt_ref_clk [get_ports gt_refclk_clk_p]}

      puts $constraints_file_late {set_false_path -from [get_clocks -filter name=~*sfpmac_*gthe2_i/RXOUTCLK] -to [get_clocks gt_refclk_clk_p]}
      puts $constraints_file_late {set_false_path -from [get_clocks gt_refclk_clk_p] -to [get_clocks -filter name=~*sfpmac_*gthe2_i/RXOUTCLK]}

      puts $constraints_file_late {set_false_path -from [get_clocks -filter name=~*sfpmac_*gthe2_i/TXOUTCLK] -to [get_clocks gt_refclk_clk_p]}
      puts $constraints_file_late {set_false_path -from [get_clocks gt_refclk_clk_p] -to [get_clocks -filter name=~*sfpmac_*gthe2_i/TXOUTCLK]}

      puts $constraints_file_late {set_false_path -from [get_clocks -of_objects [get_pins system_i/Network/sfpmac_0/coreclk_out]] -to [get_clocks -of_objects [get_pins system_i/Resets/design_aclk]]}
      puts $constraints_file_late {set_false_path -from [get_clocks -of_objects [get_pins system_i/Resets/design_aclk]] -to [get_clocks -of_objects [get_pins system_i/Network/sfpmac_0/coreclk_out]]}

      puts $constraints_file {# Main I2C Bus - 100KHz - SUME}
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports iic_scl_io]}
      puts $constraints_file {set_property SLEW SLOW [get_ports iic_scl_io]}
      puts $constraints_file {set_property DRIVE 16 [get_ports iic_scl_io]}
      puts $constraints_file {set_property PULLUP true [get_ports iic_scl_io]}
      puts $constraints_file {set_property PACKAGE_PIN AK24 [get_ports iic_scl_io]}

      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports iic_sda_io]}
      puts $constraints_file {set_property SLEW SLOW [get_ports iic_sda_io]}
      puts $constraints_file {set_property DRIVE 16 [get_ports iic_sda_io]}
      puts $constraints_file {set_property PULLUP true [get_ports iic_sda_io]}
      puts $constraints_file {set_property PACKAGE_PIN AK25 [get_ports iic_sda_io]}

      puts $constraints_file {# i2c_reset[0] - i2c_mux reset - high active}
      puts $constraints_file {# i2c_reset[1] - si5324 reset - high active}
      puts $constraints_file {set_property SLEW SLOW [get_ports {i2c_reset[*]}]}
      puts $constraints_file {set_property DRIVE 16 [get_ports {i2c_reset[*]}]}
      puts $constraints_file {set_property PACKAGE_PIN AM39 [get_ports {i2c_reset[0]}]}
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports {i2c_reset[0]}]}
      puts $constraints_file {set_property PACKAGE_PIN BA29 [get_ports {i2c_reset[1]}]}
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports {i2c_reset[1]}]}

      create_bd_port -dir O -from 1 -to 0 i2c_reset

      set num_clocks_old [get_property CONFIG.NUM_OUT_CLKS [get_bd_cells $instance/Memory/design_clk_generator]]
      set num_clocks [expr "$num_clocks_old + 1"]
      set_property -dict [list CONFIG.CLKOUT${num_clocks}_USED {true} CONFIG.CLKOUT${num_clocks}_REQUESTED_OUT_FREQ 100] [get_bd_cells $instance/Memory/design_clk_generator]
      set slow_clk [get_bd_pins $instance/Memory/design_clk_generator/clk_out${num_clocks}]

      set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells $instance/axi_ic_from_host]]
      set num_mi [expr "$num_mi_old + 1"]
      set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells $instance/axi_ic_from_host]

      #set networkConnect [tapasco::createSmartConnect "networkConnect" 1 [expr "[llength $networkIPs] + 1"] 0 2]
      #connect_bd_intf_net [get_bd_intf_pins $networkConnect/S00_AXI] [get_bd_intf_pins $instance/axi_ic_from_host/[format "M%02d_AXI" $num_mi_old]]
      #connect_bd_net [get_bd_pins $networkConnect/aclk] [get_bd_pins $instance/axi_ic_from_host/aclk]
      #connect_bd_net [get_bd_pins $networkConnect/aclk1] $slow_clk
      connect_bd_net [get_bd_pins $instance/Resets/pcie_aclk] [get_bd_pins $instance/axi_ic_from_host/[format "M%02d_ACLK" $num_mi_old]]
      connect_bd_net [get_bd_pins $instance/Resets/pcie_peripheral_aresetn] [get_bd_pins $instance/axi_ic_from_host/[format "M%02d_ARESETN" $num_mi_old]]

      set reset_inverter [tapasco::createLogicInverter "reset_inverter"]
      connect_bd_net [get_bd_pins $instance/pcie_perst] [get_bd_pins $reset_inverter/Op1]

      for {set i 0} {$i < [llength $networkIPs]} {incr i} {
        set ip [lindex $networkIPs $i]
        puts "Attaching SFP port $i to Stream $ip"

        set ip_rx [format "%s_rx" $ip]
        set ip_rx_clk [format "%s_rx_clk" $ip]
        set ip_rx_rst_n [format "%s_rx_rst_n" $ip]
        set ip_tx [format "%s_tx" $ip]
        set ip_tx_clk [format "%s_tx_clk" $ip]
        set ip_tx_rst_n [format "%s_tx_rst_n" $ip]

        create_bd_port -dir O txp_${i}
        create_bd_port -dir O txn_${i}
        create_bd_port -dir I rxp_${i}
        create_bd_port -dir I rxn_${i}

        create_bd_cell -type ip -vlnv ${vlnv} sfpmac_${i}

        if {$i > 0} {
          set_property -dict [list CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {0} CONFIG.autonegotiation {0} CONFIG.fec {0} CONFIG.Statistics_Gathering {0} CONFIG.Statistics_Gathering {false} CONFIG.TransceiverControl {true} CONFIG.DRP {false}] [get_bd_cells sfpmac_${i}]
          connect_bd_net [get_bd_pins sfpmac_0/qplllock_out] [get_bd_pins sfpmac_${i}/qplllock]
          connect_bd_net [get_bd_pins sfpmac_0/qplloutclk_out] [get_bd_pins sfpmac_${i}/qplloutclk]
          connect_bd_net [get_bd_pins sfpmac_0/qplloutrefclk_out] [get_bd_pins sfpmac_${i}/qplloutrefclk]
          connect_bd_net [get_bd_pins sfpmac_0/reset_counter_done_out] [get_bd_pins sfpmac_${i}/reset_counter_done]
          connect_bd_net [get_bd_pins sfpmac_0/txusrclk_out] [get_bd_pins sfpmac_${i}/txusrclk]
          connect_bd_net [get_bd_pins sfpmac_0/txusrclk2_out] [get_bd_pins sfpmac_${i}/txusrclk2]
          connect_bd_net [get_bd_pins sfpmac_0/txuserrdy_out] [get_bd_pins sfpmac_${i}/txuserrdy]
          connect_bd_net [get_bd_pins sfpmac_0/coreclk_out] [get_bd_pins sfpmac_${i}/coreclk]
          connect_bd_net [get_bd_pins sfpmac_0/gttxreset_out] [get_bd_pins sfpmac_${i}/gttxreset]
          connect_bd_net [get_bd_pins sfpmac_0/gtrxreset_out] [get_bd_pins sfpmac_${i}/gtrxreset]
          connect_bd_net [get_bd_pins reset_inverter/Res] [get_bd_pins sfpmac_${i}/areset]
          connect_bd_net [get_bd_pins sfpmac_${i}/areset_coreclk] [get_bd_pins sfpmac_0/gttxreset_out]
        } else {
          set_property -dict [list CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {1} CONFIG.autonegotiation {0} CONFIG.fec {0} CONFIG.Statistics_Gathering {0} CONFIG.Statistics_Gathering {false} CONFIG.TransceiverControl {true} CONFIG.DRP {false}] [get_bd_cells sfpmac_${i}]
          connect_bd_net [get_bd_ports /gt_refclk_clk_p] [get_bd_pins sfpmac_${i}/refclk_p]
          connect_bd_net [get_bd_ports /gt_refclk_clk_n] [get_bd_pins sfpmac_${i}/refclk_n]
          connect_bd_net [get_bd_pins sfpmac_${i}/reset] [get_bd_pins $reset_inverter/Res]

          set rst_inv [tapasco::createLogicInverter "rst_inverter"]
          connect_bd_net [get_bd_pins sfpmac_${i}/areset_datapathclk_out] [get_bd_pins $rst_inv/Op1]

        }

        connect_bd_net [get_bd_pins sfpmac_${i}/dclk] $slow_clk

        disconnect_bd_net /uArch/design_peripheral_aresetn_1 [get_bd_pins $ip_rx_rst_n]
        disconnect_bd_net /uArch/design_peripheral_aresetn_1 [get_bd_pins $ip_tx_rst_n]
        connect_bd_net [get_bd_pins $rst_inv/Res] [get_bd_pins $ip_rx_rst_n]
        connect_bd_net [get_bd_pins $rst_inv/Res] [get_bd_pins $ip_tx_rst_n]

        disconnect_bd_net /uArch/design_aclk_1 [get_bd_pins $ip_tx_clk]
        disconnect_bd_net /uArch/design_aclk_1 [get_bd_pins $ip_rx_clk]
        connect_bd_net [get_bd_pins sfpmac_0/coreclk_out] [get_bd_pins $ip_tx_clk]
        connect_bd_net [get_bd_pins sfpmac_0/coreclk_out] [get_bd_pins $ip_rx_clk]

        connect_bd_net [get_bd_pins sfpmac_${i}/s_axi_aclk] $slow_clk

        connect_bd_net [get_bd_ports /txp_${i}] [get_bd_pins sfpmac_${i}/txp]
        connect_bd_net [get_bd_ports /txn_${i}] [get_bd_pins sfpmac_${i}/txn]
        connect_bd_net [get_bd_ports /rxp_${i}] [get_bd_pins sfpmac_${i}/rxp]
        connect_bd_net [get_bd_ports /rxn_${i}] [get_bd_pins sfpmac_${i}/rxn]

        connect_bd_intf_net [get_bd_intf_pins $ip_tx] [get_bd_intf_pins sfpmac_${i}/s_axis_tx]
        connect_bd_intf_net [get_bd_intf_pins $ip_rx] [get_bd_intf_pins sfpmac_${i}/m_axis_rx]

        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $disable_pins $i] sfp_tx_dis_$i]
        puts $constraints_file [format {set_property IOSTANDARD LVCMOS15 [get_ports %s]} sfp_tx_dis_$i]

        puts $constraints_file [format {set_property LOC %s [get_cells -hier -filter name=~*sfpmac_%d*gthe2_i]} [lindex $locations $i] $i]

        create_bd_port -dir O sfp_tx_dis_$i
        connect_bd_net [get_bd_pins sfpmac_${i}/tx_disable] [get_bd_ports /sfp_tx_dis_$i]

        create_bd_port -dir I sfp_signal_detect_$i
        set detect_inverter [tapasco::createLogicInverter "detect_inverter_$i"]
        connect_bd_net [get_bd_pins /sfp_signal_detect_$i] [get_bd_pins $detect_inverter/Op1]
        connect_bd_net [get_bd_pins sfpmac_${i}/signal_detect] [get_bd_pins $detect_inverter/Res]

        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $signal_detect_pins $i] sfp_signal_detect_$i]
        puts $constraints_file [format {set_property IOSTANDARD LVCMOS15 [get_ports %s]} sfp_signal_detect_$i]

        create_bd_port -dir I tx_fault_$i
        connect_bd_net [get_bd_pins sfpmac_${i}/tx_fault] [get_bd_pins /tx_fault_$i]

        puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $tx_fault_pins $i] tx_fault_$i]
        puts $constraints_file [format {set_property IOSTANDARD LVCMOS15 [get_ports %s]} tx_fault_$i]

        #connect_bd_intf_net [get_bd_intf_pins $networkConnect/[format "M%02d_AXI" [expr "$i + 1"]]] [get_bd_intf_pins sfpmac_${i}/s_axi]
      }

      puts $constraints_file {set_property PACKAGE_PIN G13 [get_ports clockled]}
      puts $constraints_file {set_property IOSTANDARD LVCMOS15 [get_ports clockled]}

      close $constraints_file
      read_xdc $constraints_fn
      set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]

      close $constraints_file_late
      read_xdc $constraints_fn_late
      set_property PROCESSING_ORDER LATE [get_files $constraints_fn_late]

      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.0 SI5324Prog_0
      set_property -dict [list CONFIG.C_SCL_INERTIAL_DELAY {5} CONFIG.C_SDA_INERTIAL_DELAY {5} CONFIG.C_GPO_WIDTH {2}] [get_bd_cells SI5324Prog_0]
      create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 IIC
      connect_bd_intf_net [get_bd_intf_ports /IIC] [get_bd_intf_pins SI5324Prog_0/IIC]

      connect_bd_intf_net [get_bd_intf_pins $instance/axi_ic_from_host/[format "M%02d_AXI" $num_mi_old]] [get_bd_intf_pins SI5324Prog_0/S_AXI]

      connect_bd_net [get_bd_pins SI5324Prog_0/s_axi_aclk] [get_bd_pins $instance/Resets/pcie_aclk]
      connect_bd_net [get_bd_pins SI5324Prog_0/s_axi_aresetn] [get_bd_pins $instance/Resets/pcie_peripheral_aresetn]

      connect_bd_net [get_bd_ports /i2c_reset] [get_bd_pins SI5324Prog_0/gpo]

      #Debug
      create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:Counter:1.0 Counter_0
      create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
      set_property -dict [list CONFIG.CONST_WIDTH {32} CONFIG.CONST_VAL {150000000}] [get_bd_cells xlconstant_0]
      connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins Counter_0/overrun]
      connect_bd_net [get_bd_pins Counter_0/CLK] [get_bd_pins sfpmac_0/coreclk_out]
      connect_bd_net [get_bd_pins $rst_inv/Res] [get_bd_pins Counter_0/RST_N]
      create_bd_port -dir O clockled
      connect_bd_net [get_bd_ports /clockled] [get_bd_pins Counter_0/led]

      current_bd_instance $instance
    }
    save_bd_design
    return {}
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {

      set networkIPs [get_bd_cells -of [get_bd_intf_pins -filter {NAME =~ "*sfp_axis_rx*"} uArch/target_ip_*/*]]

      set host_addr_space [get_bd_addr_space "/PCIe/axi_pcie3_0/M_AXI"]
      set offset 0x0000000000400000

      set addr_space [get_bd_addr_segs "Network/SI5324Prog_0/S_AXI/Reg"]
      create_bd_addr_seg -range 64K -offset $offset $host_addr_space $addr_space "Network_i2c"

      #incr offset 0x10000
      #for {set i 0} {$i < [llength $networkIPs]} {incr i} {
      #  set addr_space [get_bd_addr_segs "Network/sfpmac_${i}/s_axi/Reg0"]
      #  create_bd_addr_seg -range 64K -offset $offset $host_addr_space $addr_space "Network_$i"
      #  incr offset 0x10000
      #}
    }
    return {}
  }
}

tapasco::register_plugin "platform::sfpplus::generate_sfp_cores" "post-bd"
tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"
