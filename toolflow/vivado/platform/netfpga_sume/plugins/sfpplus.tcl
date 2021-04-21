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
if {[tapasco::is_feature_enabled "SFPPLUS"]} {

  namespace eval sfpplus {

    proc is_sfpplus_supported {} {
      return true
    }

    variable available_ports 4
    variable rx_ports              {"B4" "C2" "D4" "E2"}
    variable tx_ports              {"A6" "B8" "C6" "D8"}
    variable disable_pins          {"M18" "B31" "J38" "L21"}
    variable fault_pins            {"M19" "C26" "E39" "J26"}
    variable disable_pins_voltages {"LVCMOS15" "LVCMOS15" "LVCMOS18" "LVCMOS18"}
    variable signal_detect_pins    {"N18" "L19" "J37" "H36"}
    variable locations             {"GTHE2_CHANNEL_X1Y39" "GTHE2_CHANNEL_X1Y38" "GTHE2_CHANNEL_X1Y37" "GTHE2_CHANNEL_X1Y36"}

    proc num_available_ports {} {
      variable available_ports
      return $available_ports
    }


    proc generate_cores {ports} {

      set num_streams [dict size $ports]

      create_network_config_master

      set constraints_fn "[get_property DIRECTORY [current_project]]/sfpplus.xdc"
      set constraints_file [open $constraints_fn w+]

      #Setup CLK-Ports for Ethernet-Subsystem
      puts "Adding required external ports"
      set refclk_p [create_bd_port -dir I gt_refclk_p]
      set refclk_n [create_bd_port -dir I gt_refclk_n]
      puts $constraints_file {set_property PACKAGE_PIN E10 [get_ports gt_refclk_p]}
      puts $constraints_file {create_clock -period 6.400 -name gt_refclk_p [get_ports gt_refclk_p]}
      puts $constraints_file {set_property IOSTANDARD DIFF_SSTL15 [get_ports gt_refclk_p]}

      # AXI Interconnect for Configuration
      set axi_config [tapasco::ip::create_axi_sc "axi_config" 1 [expr "1 + $num_streams"]]
      tapasco::ip::connect_sc_default_clocks $axi_config "host"

      set dclk_wiz [tapasco::ip::create_clk_wiz dclk_wiz]
      set_property -dict [list CONFIG.USE_SAFE_CLOCK_STARTUP {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 100 CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false}] $dclk_wiz

      set dclk_reset [tapasco::ip::create_rst_gen dclk_reset]

      connect_bd_net [get_bd_pins $dclk_wiz/clk_out1] [get_bd_pins $dclk_reset/slowest_sync_clk]
      connect_bd_net [get_bd_pins host_peripheral_aresetn] [get_bd_pins $dclk_reset/ext_reset_in]
      connect_bd_net [get_bd_pins host_clk] [get_bd_pins $dclk_wiz/clk_in1]

      connect_bd_intf_net [get_bd_intf_pins $axi_config/S00_AXI] [get_bd_intf_pins S_NETWORK]

      set out_inv [create_inverter out_inv]

      set axi_iic [tapasco::ip::create_axi_iic iic_controller]
      set_property -dict [list CONFIG.C_SCL_INERTIAL_DELAY {5} CONFIG.C_SDA_INERTIAL_DELAY {5} CONFIG.C_GPO_WIDTH {2}] $axi_iic

      set iic [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 IIC_0]
      connect_bd_intf_net $iic [get_bd_intf_pins $axi_iic/IIC]
      connect_bd_net [get_bd_pins $axi_iic/s_axi_aclk] [get_bd_pins host_clk]
      connect_bd_net [get_bd_pins $axi_iic/s_axi_aresetn] [get_bd_pins host_peripheral_aresetn]
      connect_bd_intf_net [get_bd_intf_pins axi_config/M00_AXI] [get_bd_intf_pins $axi_iic/S_AXI]
      make_bd_intf_pins_external [get_bd_intf_pins $axi_iic/IIC]

      delete_bd_objs  [get_bd_nets -of_objects [get_bd_pins $axi_config/aclk2]]
      connect_bd_net [get_bd_pins $dclk_wiz/clk_out1] [get_bd_pins $axi_config/aclk2]

      make_bd_pins_external [get_bd_pins $axi_iic/gpo]

      write_SI5324_Constraints

      set keys [dict keys $ports]

      variable port_number [lindex $keys 0]
      variable port_name [dict get $ports 0]
      set main_core [create_main_core $port_name $port_number 0 $constraints_file]
      for {set i 1} {$i < $num_streams} {incr i} {
        variable port_number [lindex $keys $i]
        variable port_name [dict get $ports $port_number]
        set core [create_secondary_core $port_name $port_number $i $main_core $constraints_file]
      }

      close $constraints_file
      read_xdc $constraints_fn
      set_property PROCESSING_ORDER NORMAL [get_files $constraints_fn]
    }

    # Creates the main SFP+Core (with shared logic)
    # @param port_name the name of the port for this core
    # @param port_number the physical port number
    # @param axi_index the index to connect to on the configuration interconnect
    # @param constraints_file the the file used for constraints
    # @return the created ip core
    proc create_main_core {port_name port_number axi_index constraints_file} {

      # Create the 10G Network Subsystem for the Port
      set core [tapasco::ip::create_10g_mac ethernet_${port_number}]
      set_property -dict [list CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {1} CONFIG.autonegotiation {0} CONFIG.fec {0} CONFIG.Statistics_Gathering {true} CONFIG.TransceiverControl {true} CONFIG.DRP {false}] $core

      create_connect_ports $port_number $core $constraints_file

      connect_bd_net [get_bd_ports /gt_refclk_p] [get_bd_pins $core/refclk_p]
      connect_bd_net [get_bd_ports /gt_refclk_n] [get_bd_pins $core/refclk_n]
      connect_bd_net [get_bd_pins $core/reset] [get_bd_pins host_peripheral_areset]

      connect_bd_net [get_bd_pins $core/coreclk_out] [get_bd_pins sfp_tx_clock_${port_name}] [get_bd_pins sfp_rx_clock_${port_name}]
      connect_bd_net [get_bd_pins $core/areset_datapathclk_out] [get_bd_pins out_inv/Op1]
      connect_bd_net [get_bd_pins out_inv/Res] [get_bd_pins sfp_rx_resetn_${port_name}] [get_bd_pins sfp_tx_resetn_${port_name}]


      connect_core $core $port_name $axi_index

      return $core
    }

    # Creates the a secondary SFP+-Core (without shared logic)
    # @param port_name the name of the port for this core
    # @param port_number the physical port number
    # @param axi_index the index to connect to on the configuration interconnect
    # @param main_core the main core which provides shared logic
    # @param constraints_file the file used for constraints
    proc create_secondary_core {port_name port_number axi_index main_core constraints_file} {

      # Create the 10G Network Subsystem for the Port
      set core [tapasco::ip::create_10g_mac ethernet_${port_number}]
      set_property -dict [list CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {0} CONFIG.autonegotiation {0} CONFIG.fec {0} CONFIG.Statistics_Gathering {true} CONFIG.TransceiverControl {true} CONFIG.DRP {false}] $core


      create_connect_ports $port_number $core $constraints_file

      connect_bd_net [get_bd_pins $main_core/qplllock_out]           [get_bd_pins $core/qplllock]
      connect_bd_net [get_bd_pins $main_core/qplloutclk_out]         [get_bd_pins $core/qplloutclk]
      connect_bd_net [get_bd_pins $main_core/qplloutrefclk_out]      [get_bd_pins $core/qplloutrefclk]
      connect_bd_net [get_bd_pins $main_core/reset_counter_done_out] [get_bd_pins $core/reset_counter_done]
      connect_bd_net [get_bd_pins $main_core/txusrclk_out]           [get_bd_pins $core/txusrclk]
      connect_bd_net [get_bd_pins $main_core/txusrclk2_out]          [get_bd_pins $core/txusrclk2]
      connect_bd_net [get_bd_pins $main_core/txuserrdy_out]          [get_bd_pins $core/txuserrdy]
      connect_bd_net [get_bd_pins $main_core/coreclk_out]            [get_bd_pins $core/coreclk]
      connect_bd_net [get_bd_pins $main_core/gttxreset_out]          [get_bd_pins $core/gttxreset]
      connect_bd_net [get_bd_pins $main_core/gtrxreset_out]          [get_bd_pins $core/gtrxreset]
      connect_bd_net [get_bd_pins $main_core/gttxreset_out]          [get_bd_pins $core/areset_coreclk]
      connect_bd_net [get_bd_pins host_peripheral_areset]            [get_bd_pins $core/areset]

      connect_bd_net [get_bd_pins $main_core/coreclk_out] [get_bd_pins sfp_tx_clock_${port_name}] [get_bd_pins sfp_rx_clock_${port_name}]
      connect_bd_net [get_bd_pins out_inv/Res] [get_bd_pins sfp_rx_resetn_${port_name}] [get_bd_pins sfp_tx_resetn_${port_name}]

      connect_core $core $port_name $axi_index

      return $core
    }



    # Creates and connects the bd ports for the core
    # @param port_number the physical port number
    # @param core the ip core
    # @param constraints_file the file used for constraints
    proc create_connect_ports {port_number core constraints_file} {
      variable rx_ports
      variable tx_ports
      variable disable_pins
      variable fault_pins
      variable signal_detect_pins
      variable disable_pins_voltages
      variable locations

      puts $constraints_file [format {# SFP-Port %d} $port_number]
      set txp [create_bd_port -dir O txp_${port_number}]
      set txn [create_bd_port -dir O txn_${port_number}]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $tx_ports $port_number] txp_${port_number}]
      set tx_disable [create_bd_port -dir O tx_disable_${port_number}]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $disable_pins $port_number] tx_disable_${port_number}]
      puts $constraints_file [format {set_property IOSTANDARD %s [get_ports %s]} [lindex $disable_pins_voltages $port_number] tx_disable_${port_number}]
      set rxp [create_bd_port -dir I rxp_${port_number}]
      set rxn [create_bd_port -dir I rxn_${port_number}]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $rx_ports $port_number] rxp_${port_number}]
      set tx_fault [create_bd_port -dir I tx_fault_${port_number}]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $fault_pins $port_number] tx_fault_${port_number}]
      puts $constraints_file [format {set_property IOSTANDARD %s [get_ports %s]} [lindex $disable_pins_voltages $port_number] tx_fault_${port_number}]
      set signal_detect [create_bd_port -dir I sfp_signal_detect_${port_number}]
      set detect_inverter [create_inverter detect_inverter_${port_number}]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $signal_detect_pins $port_number] sfp_signal_detect_${port_number}]
      puts $constraints_file [format {set_property IOSTANDARD %s [get_ports %s]} [lindex $disable_pins_voltages $port_number] sfp_signal_detect_${port_number}]

      connect_bd_net [get_bd_pins $core/txp] $txp
      connect_bd_net [get_bd_pins $core/txn] $txn
      connect_bd_net [get_bd_pins $core/rxp] $rxp
      connect_bd_net [get_bd_pins $core/rxn] $rxn
      connect_bd_net [get_bd_pins $core/tx_fault] $tx_fault
      connect_bd_net [get_bd_pins $core/tx_disable] $tx_disable
      connect_bd_net $signal_detect [get_bd_pins $detect_inverter/Op1]
      connect_bd_net [get_bd_pins $detect_inverter/Res] [get_bd_pins $core/signal_detect]

      puts $constraints_file [format {set_property LOC %s [get_cells -hier -filter name=~*ethernet_%d*gthe2_i]} [lindex $locations $port_number] $port_number]

      puts $constraints_file [format {set_false_path -from [get_clocks -filter name=~*ethernet_%d*gthe2_i/RXOUTCLK] -to [get_clocks gt_refclk_p]} $port_number]
      puts $constraints_file [format {set_false_path -from [get_clocks gt_refclk_p] -to [get_clocks -filter name=~*ethernet_%d*gthe2_i/RXOUTCLK]} $port_number]

      puts $constraints_file [format {set_false_path -from [get_clocks -filter name=~*ethernet_%d*gthe2_i/TXOUTCLK] -to [get_clocks gt_refclk_p]} $port_number]
      puts $constraints_file [format {set_false_path -from [get_clocks gt_refclk_p] -to [get_clocks -filter name=~*ethernet_%d*gthe2_i/TXOUTCLK]} $port_number]
    }



    # Creates the connections which are common to main and secondary cores
    # @param core the ip core
    # @param port_name the name of the port
    # @param axi_index the index to connect to on the configuration interconnect
    proc connect_core {core port_name axi_index} {
      connect_bd_net [get_bd_pins $core/tx_axis_aresetn] [get_bd_pins out_inv/Res]
      connect_bd_net [get_bd_pins $core/rx_axis_aresetn] [get_bd_pins out_inv/Res]
      connect_bd_intf_net [get_bd_intf_pins $core/m_axis_rx] [get_bd_intf_pins AXIS_RX_${port_name}]
      connect_bd_intf_net [get_bd_intf_pins $core/s_axis_tx] [get_bd_intf_pins AXIS_TX_${port_name}]
      connect_bd_intf_net [get_bd_intf_pins $core/s_axi] [get_bd_intf_pins axi_config/M[format %02d [expr "1 + $axi_index"]]_AXI]
      connect_bd_net [get_bd_pins $core/dclk] [get_bd_pins dclk_wiz/clk_out1]
      connect_bd_net [get_bd_pins $core/s_axi_aclk] [get_bd_pins dclk_wiz/clk_out1]
      connect_bd_net [get_bd_pins $core/s_axi_aresetn] [get_bd_pins dclk_reset/peripheral_aresetn]
    }

    proc create_inverter {name} {
      variable ret [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 $name]
      set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $name]
      return $ret
    }

    proc write_SI5324_Constraints {} {

      set constraints_fn  "[get_property DIRECTORY [current_project]]/si5324.xdc"
      set constraints_file [open $constraints_fn w+]

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
      puts $constraints_file {set_property SLEW SLOW [get_ports gpo_0[0]]}
      puts $constraints_file {set_property DRIVE 16 [get_ports gpo_0[0]]}
      puts $constraints_file {set_property PACKAGE_PIN AM39 [get_ports gpo_0[0]]}
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports gpo_0[0]]}
      puts $constraints_file {set_property SLEW SLOW [get_ports gpo_0[1]]}
      puts $constraints_file {set_property DRIVE 16 [get_ports gpo_0[1]]}
      puts $constraints_file {set_property PACKAGE_PIN BA29 [get_ports gpo_0[1]]}
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports gpo_0[1]]}

      close $constraints_file
      read_xdc $constraints_fn
      set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
    }

    # Create AXI connection to Host interconnect for network configuration interfaces
    proc create_network_config_master {} {
      create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_NETWORK
      set m_si [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 /host/M_NETWORK]
      set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells /host/out_ic]]
      set num_mi [expr "$num_mi_old + 1"]
      set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells /host/out_ic]
      connect_bd_intf_net $m_si [get_bd_intf_pins /host/out_ic/[format "M%02d_AXI" $num_mi_old]]
    }

    proc addressmap {{args {}}} {
      ::platform::addressmap::add_platform_component "PLATFORM_COMPONENT_SFP_NETWORK_CONTROLLER_0" 0x100000 0x10000
      ::platform::addressmap::add_platform_component "PLATFORM_COMPONENT_SFP_NETWORK_CONTROLLER_1" 0x110000 0x10000
      ::platform::addressmap::add_platform_component "PLATFORM_COMPONENT_SFP_NETWORK_CONTROLLER_2" 0x120000 0x10000
      set args [lappend args "M_NETWORK" [list 0x100000 0x10000 0x10000 "PLATFORM_COMPONENT_SFP_NETWORK_CONTROLLER"]]
      return $args
    }


  }

  tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"

}
