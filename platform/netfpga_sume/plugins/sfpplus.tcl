  set vlnv_2016_4 "xilinx.com:ip:axi_10g_ethernet:3.1"
  set vlnv_2017_2 "xilinx.com:ip:axi_10g_ethernet:3.1"

  if {[tapasco::is_feature_enabled "SFPPLUS"]} {
    proc create_custom_subsystem_network {{args {}}} {
        set disable_pins {"M18" "B31" "J38" "L21"}
        set disable_pins_voltages {"LVCMOS15" "LVCMOS15" "LVCMOS18" "LVCMOS18"}
        set tx_fault_pins {"M19" "C26" "E39" "J26"}
        set signal_detect_pins {"N18" "L19" "J37" "H36"}
        set rx_pins_p {"B4" "C2" "D4" "E2"}
        set tx_pins_p {"A6" "B8" "C6" "D8"}
        set locations {"GTHE2_CHANNEL_X1Y39" "GTHE2_CHANNEL_X1Y38" "GTHE2_CHANNEL_X1Y37" "GTHE2_CHANNEL_X1Y36"}

        set networkStreams [get_bd_intf_pins -filter {NAME =~ "*sfp_axis_*rx*"} -of_objects [get_bd_cells /arch/target_ip_*]]

        set networkIPs [list]

        for {set i 0} {$i < [llength $networkStreams]} {incr i} {
          set stream [lindex $networkStreams $i]
          regexp {/arch/(.+)/sfp_axis(_.+)?_rx} $stream matched ip sfp_name
          puts "Found SFP Port"
          puts [format "IP: %s" $ip]
          puts [format "SFP Name: %s" $sfp_name]
          lappend networkIPs [format "/arch/%s/sfp_axis%s" $ip $sfp_name]
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

        puts $constraints_file {set_property PACKAGE_PIN E10 [get_ports gt_refclk_clk_p]}
        puts $constraints_file {create_clock -period 6.400 -name gt_ref_clk [get_ports gt_refclk_clk_p]}

        puts $constraints_file_late {set_false_path -from [get_clocks -filter name=~*sfpmac_*gthe2_i/RXOUTCLK] -to [get_clocks gt_refclk_clk_p]}
        puts $constraints_file_late {set_false_path -from [get_clocks gt_refclk_clk_p] -to [get_clocks -filter name=~*sfpmac_*gthe2_i/RXOUTCLK]}

        puts $constraints_file_late {set_false_path -from [get_clocks -filter name=~*sfpmac_*gthe2_i/TXOUTCLK] -to [get_clocks gt_refclk_clk_p]}
        puts $constraints_file_late {set_false_path -from [get_clocks gt_refclk_clk_p] -to [get_clocks -filter name=~*sfpmac_*gthe2_i/TXOUTCLK]}

        puts $constraints_file {# Main I2C Bus - 100KHz - SUME}
        puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports IIC_0_scl_io]}
        puts $constraints_file {set_property SLEW SLOW [get_ports IIC_0_scl_io]}
        puts $constraints_file {set_property DRIVE 16 [get_ports IIC_0_scl_io]}
        puts $constraints_file {set_property PULLUP true [get_ports IIC_0_scl_io]}
        puts $constraints_file {set_property PACKAGE_PIN AK24 [get_ports IIC_0_scl_io]}

        puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports IIC_0_sda_io]}
        puts $constraints_file {set_property SLEW SLOW [get_ports IIC_0_sda_io]}
        puts $constraints_file {set_property DRIVE 16 [get_ports IIC_0_sda_io]}
        puts $constraints_file {set_property PULLUP true [get_ports IIC_0_sda_io]}
        puts $constraints_file {set_property PACKAGE_PIN AK25 [get_ports IIC_0_sda_io]}

        puts $constraints_file {# i2c_reset[0] - i2c_mux reset - high active}
        puts $constraints_file {# i2c_reset[1] - si5324 reset - high active}
        puts $constraints_file {set_property SLEW SLOW [get_ports {i2c_reset[*]}]}
        puts $constraints_file {set_property DRIVE 16 [get_ports {i2c_reset[*]}]}
        puts $constraints_file {set_property PACKAGE_PIN AM39 [get_ports {i2c_reset[0]}]}
        puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports {i2c_reset[0]}]}
        puts $constraints_file {set_property PACKAGE_PIN BA29 [get_ports {i2c_reset[1]}]}
        puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports {i2c_reset[1]}]}

        puts "Adding required external ports"
        create_bd_port -dir I gt_refclk_clk_p
        create_bd_port -dir I gt_refclk_clk_n
        set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_clk_p]
        set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_clk_n]

        puts "Instantiating clock wizard for 100MHz dclk"
        set dclk_wiz [tapasco::ip::create_clk_wiz dclk_wiz]
        set_property -dict [list CONFIG.USE_SAFE_CLOCK_STARTUP {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 100 \
                          CONFIG.USE_LOCKED {false} \
                          CONFIG.USE_RESET {false}] $dclk_wiz
        connect_bd_net [get_bd_pins host_clk] [get_bd_pins $dclk_wiz/clk_in1]
        set slow_clk [get_bd_pins $dclk_wiz/clk_out1]


        for {set i 0} {$i < [llength $networkIPs]} {incr i} {
          set ip [lindex $networkIPs $i]
          puts "Attaching SFP port $i to Stream $ip"

          set ip_rx [format "%s_rx" $ip]
          set ip_tx [format "%s_tx" $ip]
          set ip_rx_clk [format "%s_rx_aclk" $ip]
          set ip_rx_rst_n [format "%s_rx_aresetn" $ip]
          set ip_tx_clk [format "%s_tx_aclk" $ip]
          set ip_tx_rst_n [format "%s_tx_aresetn" $ip]

          create_bd_port -dir O txp_${i}
          create_bd_port -dir O txn_${i}
          create_bd_port -dir I rxp_${i}
          create_bd_port -dir I rxn_${i}

          set sfpmac [tapasco::ip::create_10g_mac sfpmac_${i}]

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
            connect_bd_net [get_bd_pins host_peripheral_areset] [get_bd_pins sfpmac_${i}/areset]
            connect_bd_net [get_bd_pins sfpmac_${i}/areset_coreclk] [get_bd_pins sfpmac_0/gttxreset_out]
          } else {
            set_property -dict [list CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {1} CONFIG.autonegotiation {0} CONFIG.fec {0} CONFIG.Statistics_Gathering {0} CONFIG.Statistics_Gathering {false} CONFIG.TransceiverControl {true} CONFIG.DRP {false}] [get_bd_cells sfpmac_${i}]
            connect_bd_net [get_bd_ports /gt_refclk_clk_p] [get_bd_pins sfpmac_${i}/refclk_p]
            connect_bd_net [get_bd_ports /gt_refclk_clk_n] [get_bd_pins sfpmac_${i}/refclk_n]
            connect_bd_net [get_bd_pins sfpmac_${i}/reset] [get_bd_pins host_peripheral_areset]

            #puts $constraints_file_late {set_false_path -from [get_clocks -of_objects [get_pins system_i/Network/sfpmac_0/coreclk_out]] -to [get_clocks -of_objects [get_pins system_i/Resets/design_aclk]]}
            #puts $constraints_file_late {set_false_path -from [get_clocks -of_objects [get_pins system_i/Resets/design_aclk]] -to [get_clocks -of_objects [get_pins system_i/Network/sfpmac_0/coreclk_out]]}

            set rst_inv [tapasco::ip::create_logic_vector "rst_inv"]
            set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $rst_inv]
            connect_bd_net [get_bd_pins sfpmac_${i}/areset_datapathclk_out] [get_bd_pins $rst_inv/Op1]
          }

          connect_bd_net [get_bd_pins sfpmac_${i}/dclk] $slow_clk


          disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins $ip_rx_rst_n]] [get_bd_pins $ip_rx_rst_n]
          disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins $ip_tx_rst_n]] [get_bd_pins $ip_tx_rst_n]
          connect_bd_net [get_bd_pins $rst_inv/Res] [get_bd_pins $ip_rx_rst_n]
          connect_bd_net [get_bd_pins $rst_inv/Res] [get_bd_pins $ip_tx_rst_n]

          disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins $ip_tx_clk]] [get_bd_pins $ip_tx_clk]
          disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins $ip_rx_clk]] [get_bd_pins $ip_rx_clk]
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
          puts $constraints_file [format {set_property IOSTANDARD %s [get_ports %s]} [lindex $disable_pins_voltages $i] sfp_tx_dis_$i]

          puts $constraints_file [format {set_property LOC %s [get_cells -hier -filter name=~*sfpmac_%d*gthe2_i]} [lindex $locations $i] $i]

          create_bd_port -dir O sfp_tx_dis_$i
          connect_bd_net [get_bd_pins sfpmac_${i}/tx_disable] [get_bd_ports /sfp_tx_dis_$i]

          create_bd_port -dir I sfp_signal_detect_$i
          set detect_inverter [tapasco::ip::create_logic_vector "detect_inverter_$i"]
          set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $detect_inverter]
          connect_bd_net [get_bd_pins /sfp_signal_detect_$i] [get_bd_pins $detect_inverter/Op1]
          connect_bd_net [get_bd_pins sfpmac_${i}/signal_detect] [get_bd_pins $detect_inverter/Res]

          puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $signal_detect_pins $i] sfp_signal_detect_$i]
          puts $constraints_file [format {set_property IOSTANDARD %s [get_ports %s]} [lindex $disable_pins_voltages $i] sfp_signal_detect_$i]

          create_bd_port -dir I tx_fault_$i
          connect_bd_net [get_bd_pins sfpmac_${i}/tx_fault] [get_bd_pins /tx_fault_$i]

          puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $tx_fault_pins $i] tx_fault_$i]
          puts $constraints_file [format {set_property IOSTANDARD %s [get_ports %s]} [lindex $disable_pins_voltages $i] tx_fault_$i]

        }

        puts $constraints_file {set_property PACKAGE_PIN G13 [get_ports clockled]}
        puts $constraints_file {set_property IOSTANDARD LVCMOS15 [get_ports clockled]}

        close $constraints_file
        read_xdc $constraints_fn
        set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]

        close $constraints_file_late
        read_xdc $constraints_fn_late
        set_property PROCESSING_ORDER LATE [get_files $constraints_fn_late]

        set si5324prog [tapasco::ip::create_axi_iic "SI5324Prog"]
        set_property -dict [list CONFIG.C_SCL_INERTIAL_DELAY {5} CONFIG.C_SDA_INERTIAL_DELAY {5} CONFIG.C_GPO_WIDTH {2}] $si5324prog

        create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 IIC
        connect_bd_intf_net [get_bd_intf_pin IIC] [get_bd_intf_pins $si5324prog/IIC]

        create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_SI5324
        connect_bd_intf_net [get_bd_intf_pin S_SI5324] [get_bd_intf_pins $si5324prog/S_AXI]

        connect_bd_net [get_bd_pins $si5324prog/s_axi_aclk] [get_bd_pins host_clk]
        connect_bd_net [get_bd_pins $si5324prog/s_axi_aresetn] [get_bd_pins host_peripheral_aresetn]

        create_bd_pin -dir O -from 1 -to 0 i2c_reset
        connect_bd_net [get_bd_pins $si5324prog/gpo] [get_bd_pin i2c_reset]

        puts "Fix connections in the rest of the design"
        set inst [current_bd_instance -quiet .]
        current_bd_instance -quiet
        make_bd_intf_pins_external  [get_bd_intf_pins network/IIC]

        set m_si [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 host/M_SI5324]

        set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells host/out_ic]]
        set num_mi [expr "$num_mi_old + 1"]
        set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells host/out_ic]
        connect_bd_intf_net $m_si [get_bd_intf_pins host/out_ic/[format "M%02d_AXI" $num_mi_old]]
        connect_bd_net [get_bd_pins host/host_clk] [get_bd_pins host/out_ic/[format "M%02d_ACLK" $num_mi_old]]
        connect_bd_net [get_bd_pins host/host_peripheral_aresetn] [get_bd_pins host/out_ic/[format "M%02d_ARESETN" $num_mi_old]]

        current_bd_instance -quiet $inst

        puts "SFP connections completed"
      return {}
    }
}

namespace eval sfpplus {
  namespace export addressmap

  proc addressmap {args} {
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {
        set args [lappend args "M_SI5324" [list 0x22ff000 0 0 ""]]
        puts $args
    }
    return $args
  }
}

tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"
