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

  namespace eval 100g {

    variable available_ports 1
    variable cmac_cores            {"CMACE4_X0Y3"}
    variable gt_groups             {"X0Y28~X0Y31"}
    variable refclk_pins           {"N36"}

    proc num_available_ports {} {
      variable available_ports
      return $available_ports
    }

    proc generate_cores {ports} {

      set num_streams [dict size $ports]

      puts "Generating $num_streams SFPPLUS cores"
      set constraints_fn "[get_property DIRECTORY [current_project]]/sfpplus.xdc"
      set constraints_file [open $constraints_fn w+]

      # QSFP Ports
      set const_one [tapasco::ip::create_constant const_one 1 1]

      # Clocking wizard for creating clock dclk; Used for dclk and AXI-Lite clocks of core
      set dclk_wiz [tapasco::ip::create_clk_wiz dclk_wiz]
      set_property -dict [list \
        CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 100 \
        CONFIG.USE_LOCKED {false} \
        CONFIG.USE_RESET {false} \
      ] $dclk_wiz

      # Reset Generator for dclk reset
      set dclk_reset [tapasco::ip::create_rst_gen dclk_reset]

      connect_bd_net [get_bd_pins $dclk_wiz/clk_out1] [get_bd_pins $dclk_reset/slowest_sync_clk]
      connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $dclk_reset/ext_reset_in]
      connect_bd_net [get_bd_pins design_clk] [get_bd_pins $dclk_wiz/clk_in1]

      set first_port 0
      foreach port [dict keys $ports] {
        set name [dict get $ports $port]
        generate_core $port $name $first_port $constraints_file
        incr first_port 1
      }

      close $constraints_file
      read_xdc $constraints_fn
      set_property PROCESSING_ORDER NORMAL [get_files $constraints_fn]
    }

    # Generate a SFP+-Core to handle the ports of one physical cage
    # @param physical_port the number of the physical cage
    # @param name name of the port
    # @param first_port the first free master on the AXI-Lite Config interconnect
    # @param constraints_file the file used for constraints
    proc generate_core {physical_port name first_port constraints_file} {
      variable refclk_pins
      variable cmac_cores
      variable gt_groups

      # Create and configure core
      set core [tapasco::ip::create_100g_ethernet ethernet_$physical_port]

      # Create and constrain refclk pin
      set gt_refclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 qsfp${physical_port}_161mhz]
      set_property CONFIG.FREQ_HZ 161132812 $gt_refclk
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $refclk_pins $physical_port] qsfp${physical_port}_161mhz_clk_p]

      set_property -dict [list \
        CONFIG.CMAC_CAUI4_MODE {1} \
        CONFIG.NUM_LANES {4x25} \
        CONFIG.USER_INTERFACE {AXIS} \
        CONFIG.GT_REF_CLK_FREQ {161.1328125} \
        CONFIG.TX_FLOW_CONTROL {0} \
        CONFIG.RX_FLOW_CONTROL {0} \
        CONFIG.INCLUDE_RS_FEC {1} \
        CONFIG.ENABLE_AXI_INTERFACE {0} \
        CONFIG.INCLUDE_STATISTICS_COUNTERS {0} \
        CONFIG.RX_MAX_PACKET_LEN {16383} \
        CONFIG.CMAC_CORE_SELECT [lindex $cmac_cores $physical_port] \
        CONFIG.GT_GROUP_SELECT [lindex $gt_groups $physical_port] \
      ] $core

      # Connect core
      connect_bd_net [get_bd_pins $core/sys_reset] [get_bd_pins dclk_reset/peripheral_reset]
      connect_bd_net [get_bd_pins $core/drp_clk] [get_bd_pins dclk_wiz/clk_out1]
      connect_bd_net [get_bd_pins $core/init_clk] [get_bd_pins dclk_wiz/clk_out1]

      connect_bd_intf_net $gt_refclk [get_bd_intf_pins $core/gt_ref_clk]
      make_bd_intf_pins_external [get_bd_intf_pins $core/gt_serial_port]

      connect_bd_intf_net [get_bd_intf_pins $core/axis_rx] [get_bd_intf_pins AXIS_RX_${name}]
      connect_bd_intf_net [get_bd_intf_pins $core/axis_tx] [get_bd_intf_pins AXIS_TX_${name}]
      connect_bd_net [get_bd_pins $core/gt_txusrclk2] [get_bd_pins $core/rx_clk]

      # clock and resets to AXIS interconnect
      connect_bd_net [get_bd_pins $core/gt_txusrclk2] [get_bd_pins /Network/sfp_tx_clock_${name}]
      connect_bd_net [get_bd_pins $core/gt_txusrclk2] [get_bd_pins /Network/sfp_rx_clock_${name}]

      set out_inv [create_inverter tx_reset_inverter_${name}]
      connect_bd_net [get_bd_pins $core/usr_tx_reset] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_tx_resetn_${name}] [get_bd_pins $out_inv/Res]

      set out_inv [create_inverter rx_reset_inverter_${name}]
      connect_bd_net [get_bd_pins $core/usr_rx_reset] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_rx_resetn_${name}] [get_bd_pins $out_inv/Res]

      connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins $core/ctl_rx_enable]
      connect_bd_net [get_bd_pins $core/stat_rx_aligned] [get_bd_pins $core/ctl_tx_enable]

      connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins $core/ctl_rx_rsfec_enable]
      connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins $core/ctl_rx_rsfec_enable_correction]
      connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins $core/ctl_rx_rsfec_enable_indication]
      connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins $core/ctl_tx_rsfec_enable]

      set aligned_inverter [tapasco::ip::create_logic_vector aligned_inverter_$physical_port]
      set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] $aligned_inverter
      connect_bd_net [get_bd_pins $core/stat_rx_aligned] [get_bd_pins $aligned_inverter/Op1]
      connect_bd_net [get_bd_pins $aligned_inverter/Res] [get_bd_pins $core/ctl_tx_send_rfi]
    }

    proc create_inverter {name} {
      variable ret [tapasco::ip::create_logic_vector $name]
      set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $name]
      return $ret
    }
  }
}
