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

  namespace eval Aurora {

    variable available_ports 2
    variable start_quad            {"Quad_X0Y10" "Quad_X0Y11"}
    variable start_lane            {"X0Y40" "X0Y44"}
    variable refclk_pins           {"R40" "M42"}
    variable refclk_en_n_pins      {"H32" "H30"}
    variable refclk_sel_pins       {"G32" "G33"}

    proc num_available_ports {} {
      variable available_ports
      return $available_ports
    }

    proc generate_cores {ports} {

      set num_streams [dict size $ports]

      puts "Generating $num_streams SFPPLUS cores"
      set constraints_fn "[get_property DIRECTORY [current_project]]/sfpplus.xdc"
      set constraints_file [open $constraints_fn w+]

      # Clocking wizard for creating clock dclk; Used for dclk and AXI-Lite clocks of core
      set dclk_wiz [tapasco::ip::create_clk_wiz dclk_wiz]
      set_property -dict [list CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
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
      variable start_quad
      variable start_lane
      variable refclk_pins
      variable refclk_en_n_pins
      variable refclk_sel_pins

      set const_zero [tapasco::ip::create_constant const_zero_$physical_port 1 0]
      set const_one [tapasco::ip::create_constant const_one_$physical_port 1 1]

      # Create and constrain refclk pin
      set gt_refclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 qsfp${physical_port}_161mhz]
      set_property CONFIG.FREQ_HZ 161132813 $gt_refclk
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $refclk_pins $physical_port] qsfp${physical_port}_161mhz_clk_p]

      # Enable refclock
      set refclk_en_n [create_bd_port -dir O refclk_en_n_$physical_port]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $refclk_en_n_pins $physical_port] refclk_en_n_$physical_port]
      puts $constraints_file [format {set_property IOSTANDARD LVCMOS18 [get_ports %s]} refclk_en_n_$physical_port]
      connect_bd_net [get_bd_pins $const_zero/dout] $refclk_en_n

      # Select refclock frequency (0 = 156.25 MHz, 1 = 161.132812 MHz)
      set refclk_sel [create_bd_port -dir O refclk_sel_$physical_port]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $refclk_sel_pins $physical_port] refclk_sel_$physical_port]
      puts $constraints_file [format {set_property IOSTANDARD LVCMOS18 [get_ports %s]} refclk_sel_$physical_port]
      connect_bd_net [get_bd_pins $const_one/dout] $refclk_sel

      # Create and configure core
      set core [tapasco::ip::create_aurora aurora_$physical_port]

      set_property -dict [list \
        CONFIG.C_AURORA_LANES {4} \
        CONFIG.C_LINE_RATE {25.78125} \
        CONFIG.C_USE_BYTESWAP {true} \
        CONFIG.C_REFCLK_FREQUENCY {161.1328125} \
        CONFIG.C_INIT_CLK {100} \
        CONFIG.SupportLevel {1} \
        CONFIG.RX_EQ_MODE {LPM} \
        CONFIG.C_UCOLUMN_USED {left} \
        CONFIG.C_START_QUAD [lindex $start_quad $physical_port] \
        CONFIG.C_START_LANE [lindex $start_lane $physical_port] \
      ] $core

      connect_bd_intf_net $gt_refclk [get_bd_intf_pins $core/GT_DIFF_REFCLK1]
      connect_bd_net [get_bd_pins $core/reset_pb] [get_bd_pins dclk_reset/peripheral_reset]
      connect_bd_net [get_bd_pins $core/pma_init] [get_bd_pins dclk_reset/peripheral_reset]
      make_bd_intf_pins_external [get_bd_intf_pins $core/GT_SERIAL_RX]
      make_bd_intf_pins_external [get_bd_intf_pins $core/GT_SERIAL_TX]
      connect_bd_net [get_bd_pins $core/init_clk] [get_bd_pins dclk_wiz/clk_out1]

      # Connect core
      connect_bd_intf_net [get_bd_intf_pins $core/USER_DATA_M_AXIS_RX] [get_bd_intf_pins AXIS_RX_${name}]
      connect_bd_intf_net [get_bd_intf_pins $core/USER_DATA_S_AXIS_TX] [get_bd_intf_pins AXIS_TX_${name}]

      connect_bd_net [get_bd_pins $core/user_clk_out] [get_bd_pins /Network/sfp_tx_clock_${name}]
      connect_bd_net [get_bd_pins $core/user_clk_out] [get_bd_pins /Network/sfp_rx_clock_${name}]

      set out_inv [create_inverter sys_reset_inverter_${name}]
      connect_bd_net [get_bd_pins $core/sys_reset_out] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_tx_resetn_${name}] [get_bd_pins $out_inv/Res]
      connect_bd_net [get_bd_pins /Network/sfp_rx_resetn_${name}] [get_bd_pins $out_inv/Res]
    }

    proc create_inverter {name} {
      variable ret [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 $name]
      set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $name]
      return $ret
    }
  }
}
