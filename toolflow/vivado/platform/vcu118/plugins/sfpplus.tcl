# Copyright (c) 2014-2021 Embedded Systems and Applications, TU Darmstadt.
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

  proc is_sfpplus_supported {} {
    return true
  }

  variable available_ports 8
  variable refclk_pins           {"U38" "U104"}
  variable gt_quads              {"Quad_X1Y12" "Quad_X1Y13"}
  variable gt_lanes              {"X1Y48" "X1Y49" "X1Y50" "X1Y51" "X1Y52" "X1Y53" "X1Y54" "X1Y55"}

  proc num_available_ports {} {
    variable available_ports
    return $available_ports
  }

  proc generate_cores {ports} {

    set num_streams [dict size $ports]

    create_network_config_master

    puts "Generating $num_streams SFPPLUS cores"
    set constraints_fn "[get_property DIRECTORY [current_project]]/sfpplus.xdc"
    set constraints_file [open $constraints_fn w+]

    # AXI Interconnect for Configuration
    set axi_config [tapasco::ip::create_axi_ic axi_config 1 $num_streams]

    # Clocking wizard for creating clock dclk; Used for dclk and AXI-Lite clocks of core
    set dclk_wiz [tapasco::ip::create_clk_wiz dclk_wiz]
    set_property -dict [list CONFIG.USE_SAFE_CLOCK_STARTUP {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 100 CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false}] $dclk_wiz

    # Reset Generator for dclk reset
    set dclk_reset [tapasco::ip::create_rst_gen dclk_reset]

    connect_bd_net [get_bd_pins $dclk_wiz/clk_out1] [get_bd_pins $dclk_reset/slowest_sync_clk]
    connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $dclk_reset/ext_reset_in]
    connect_bd_net [get_bd_pins design_clk] [get_bd_pins $dclk_wiz/clk_in1]
    connect_bd_net [get_bd_pins $axi_config/M*_ACLK] [get_bd_pins $dclk_wiz/clk_out1]
    connect_bd_net [get_bd_pins $axi_config/M*_ARESETN] [get_bd_pins $dclk_reset/peripheral_aresetn]

    connect_bd_intf_net [get_bd_intf_pins $axi_config/S00_AXI] [get_bd_intf_pins S_NETWORK]
    connect_bd_net [get_bd_pins $axi_config/S00_ACLK] [get_bd_pins design_clk]
    connect_bd_net [get_bd_pins $axi_config/S00_ARESETN] [get_bd_pins design_interconnect_aresetn]
    connect_bd_net [get_bd_pins $axi_config/ACLK] [get_bd_pins design_clk]
    connect_bd_net [get_bd_pins $axi_config/ARESETN] [get_bd_pins design_interconnect_aresetn]

    # Cores need constant clock select input
    set const_clksel [tapasco::ip::create_constant const_clksel 3 5]

    # Generate SFP+-Cores
    # Each core can handle (up to) all four ports of one physical cage
    set first_port 0
    for {set i 0} {$i < 2} {incr i} {
      set ports_created [generate_core $i $ports $first_port $constraints_file]
      incr first_port $ports_created
    }

    close $constraints_file
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER NORMAL [get_files $constraints_fn]
  }

  # Generate a SFP+-Core to handle the ports of one physical cage
  # @param number the number of the physical cage
  # @param physical_ports the numbers of all physical_ports which are required in the design
  # @param first_port the first free master on the AXI-Lite Config interconnect
  # @param constraints_file git stthe file used for constraints
  # @return the number of ports created with this core
  proc generate_core {number physical_ports first_port constraints_file} {
    variable refclk_pins
    variable gt_quads
    variable gt_lanes

    # Select physical_ports which will be handled by this core
    set ports [list]

    for {set i 0} {$i < 4} {incr i} {
      set port_number [expr ($number * 4) + $i]
      if {[dict exists $physical_ports $port_number]} {
        lappend ports $port_number
      }
    }

    set num_ports [llength $ports]

    # No ports for this core found -> abort
    if {$num_ports == 0} {
      return 0
    }

    # Create and constrain refclk pin
    set gt_refclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_refclk_$number]
    set_property CONFIG.FREQ_HZ 156250000 $gt_refclk
    puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $refclk_pins $number] gt_refclk_${number}_clk_p]


    # Create and configure core
    set core [tapasco::ip::create_xxv_ethernet ethernet_$number]

    set_property -dict [list \
      CONFIG.NUM_OF_CORES $num_ports \
      CONFIG.LINE_RATE {10} \
      CONFIG.BASE_R_KR {BASE-R} \
      CONFIG.INCLUDE_AXI4_INTERFACE {1} \
      CONFIG.INCLUDE_STATISTICS_COUNTERS {0} \
      CONFIG.GT_REF_CLK_FREQ {156.25} \
      CONFIG.GT_GROUP_SELECT [lindex $gt_quads $number]
    ] $core

    # Configure GT lanes based on required ports
    set lanes [list]
    for {set i 0} {$i < $num_ports} {incr i} {
      set lane_index [format %01s [expr $i + 1]]
      set gt_lane [lindex $gt_lanes [lindex $ports $i]]
      lappend lanes CONFIG.LANE${lane_index}_GT_LOC $gt_lane
    }
    set_property -dict $lanes $core

    connect_bd_intf_net $gt_refclk [get_bd_intf_pins $core/gt_ref_clk]
    connect_bd_net [get_bd_pins $core/sys_reset] [get_bd_pins dclk_reset/peripheral_reset]
    make_bd_intf_pins_external [get_bd_intf_pins $core/gt_rx]
    make_bd_intf_pins_external [get_bd_intf_pins $core/gt_tx]
    connect_bd_net [get_bd_pins $core/dclk] [get_bd_pins dclk_wiz/clk_out1]

    set addr 0x2500000

    # Connect core
    for {set i 0} {$i < $num_ports} {incr i} {
      set name [dict get $physical_ports [lindex $ports $i]]

      # Register SFP connections as platform components for use in runtime
      ::platform::addressmap::add_platform_component [format "PLATFORM_COMPONENT_SFP_NETWORK_CONTROLLER_%d" $i] $addr 0x10000
      incr addr 0x10000

      connect_bd_intf_net [get_bd_intf_pins $core/axis_rx_${i}] [get_bd_intf_pins AXIS_RX_${name}]
      connect_bd_intf_net [get_bd_intf_pins $core/axis_tx_${i}] [get_bd_intf_pins AXIS_TX_${name}]
      connect_bd_intf_net [get_bd_intf_pins $core/s_axi_${i}] [get_bd_intf_pins /Network/AXI_Config/M[format %02d [expr $first_port + $i]]_AXI]
      connect_bd_net [get_bd_pins $core/s_axi_aclk_${i}] [get_bd_pins dclk_wiz/clk_out1]
      connect_bd_net [get_bd_pins $core/s_axi_aresetn_${i}] [get_bd_pins dclk_reset/peripheral_aresetn]
      connect_bd_net [get_bd_pins $core/tx_clk_out_${i}] [get_bd_pins $core/rx_core_clk_${i}]
      connect_bd_net [get_bd_pins $core/txoutclksel_in_${i}] [get_bd_pins const_clksel/dout]
      connect_bd_net [get_bd_pins $core/rxoutclksel_in_${i}] [get_bd_pins const_clksel/dout]

      connect_bd_net [get_bd_pins $core/tx_clk_out_${i}] [get_bd_pins /Network/sfp_tx_clock_${name}]
      connect_bd_net [get_bd_pins $core/tx_clk_out_${i}] [get_bd_pins /Network/sfp_rx_clock_${name}]

      set out_inv [create_inverter tx_reset_inverter_${name}]
      connect_bd_net [get_bd_pins $core/user_tx_reset_${i}] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_tx_resetn_${name}] [get_bd_pins $out_inv/Res]

      set out_inv [create_inverter rx_reset_inverter_${name}]
      connect_bd_net [get_bd_pins $core/user_rx_reset_${i}] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_rx_resetn_${name}] [get_bd_pins $out_inv/Res]
    }
    return $num_ports
  }

  proc create_inverter {name} {
    variable ret [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 $name]
    set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $name]
    return $ret
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
    set args [lappend args "M_NETWORK" [list 0x2500000 0 0 ""]]
    return $args
  }

  tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"

}