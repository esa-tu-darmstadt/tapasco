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

    variable available_ports 4
    variable refclk_pins           {"P13" "V13" "AD13" "AJ15"}
    variable cmac_cores            {"CMACE4_X0Y7" "CMACE4_X0Y6" "CMACE4_X0Y4" "CMACE4_X0Y2"}
    variable gt_groups             {"X1Y44~X1Y47" "X1Y36~X1Y39" "X1Y24~X1Y27" "X1Y16~X1Y19"}
    variable fpga_i2c_master       "E17"
    variable qsfp_ctl_en           "C18"
    variable qsfp_rst              {"A21" "A19" "B16" "C19"}
    variable qsfp_lp               "B18"

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
      set const_zero [tapasco::ip::create_constant const_zero 1 0]
      set const_one [tapasco::ip::create_constant const_one 1 1]

      variable fpga_i2c_master
      variable qsfp_ctl_en
      variable qsfp_lp

      set port_fpga_i2c_master [create_bd_port -dir O fpga_i2c_master]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports fpga_i2c_master]} $fpga_i2c_master]
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports fpga_i2c_master]}
      connect_bd_net [get_bd_pins $const_zero/dout] $port_fpga_i2c_master

      set port_qsfp_ctl_en [create_bd_port -dir O qsfp_ctl_en]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports qsfp_ctl_en]} $qsfp_ctl_en]
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports qsfp_ctl_en]}
      connect_bd_net [get_bd_pins $const_one/dout] $port_qsfp_ctl_en

      set port_qsfp_lp [create_bd_port -dir O qsfp_lp]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports qsfp_lp]} $qsfp_lp]
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports qsfp_lp]}
      connect_bd_net [get_bd_pins $const_zero/dout] $port_qsfp_lp

      # Clocking wizard for creating clock dclk; Used for dclk and AXI-Lite clocks of core
      set dclk_wiz [tapasco::ip::create_clk_wiz dclk_wiz]
      set_property -dict [list CONFIG.USE_SAFE_CLOCK_STARTUP {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 100 CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false}] $dclk_wiz

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
      variable qsfp_rst

      set port_qsfp_rst [create_bd_port -dir O qsfp_rst_l_$physical_port]
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $qsfp_rst $physical_port] qsfp_rst_l_$physical_port]
      puts $constraints_file [format {set_property IOSTANDARD LVCMOS18 [get_ports %s]} qsfp_rst_l_$physical_port]

      # Create and constrain refclk pin
      set gt_refclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_refclk_$physical_port]
      set_property CONFIG.FREQ_HZ 322265625 $gt_refclk
      puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports %s]} [lindex $refclk_pins $physical_port] gt_refclk_${physical_port}_clk_p]

      # Create and configure core
      set core [tapasco::ip::create_100g_ethernet ethernet_$physical_port]

      set_property -dict [list \
        CONFIG.CMAC_CAUI4_MODE {1} \
        CONFIG.NUM_LANES {4x25} \
        CONFIG.USER_INTERFACE {AXIS} \
        CONFIG.GT_REF_CLK_FREQ {322.265625} \
        CONFIG.TX_FLOW_CONTROL {0} \
        CONFIG.RX_FLOW_CONTROL {0} \
        CONFIG.INCLUDE_RS_FEC {1} \
        CONFIG.ENABLE_AXI_INTERFACE {0} \
        CONFIG.INCLUDE_STATISTICS_COUNTERS {0} \
        CONFIG.RX_MAX_PACKET_LEN {16383} \
        CONFIG.CMAC_CORE_SELECT [lindex $cmac_cores $physical_port] \
        CONFIG.GT_GROUP_SELECT [lindex $gt_groups $physical_port]
        ] $core

      connect_bd_intf_net $gt_refclk [get_bd_intf_pins $core/gt_ref_clk]
      connect_bd_net [get_bd_pins $core/sys_reset] [get_bd_pins dclk_reset/peripheral_reset]
      if { [::tapasco::vivado_is_newer "2020.1"] == 1} {
        make_bd_intf_pins_external [get_bd_intf_pins $core/gt_serial_port]
      } else {
        make_bd_intf_pins_external [get_bd_intf_pins $core/gt_rx]
        make_bd_intf_pins_external [get_bd_intf_pins $core/gt_tx]
      }
      connect_bd_net [get_bd_pins $core/drp_clk] [get_bd_pins dclk_wiz/clk_out1]
      connect_bd_net [get_bd_pins $core/init_clk] [get_bd_pins dclk_wiz/clk_out1]

      # Connect core
      connect_bd_intf_net [get_bd_intf_pins $core/axis_rx] [get_bd_intf_pins AXIS_RX_${name}]
      connect_bd_intf_net [get_bd_intf_pins $core/axis_tx] [get_bd_intf_pins AXIS_TX_${name}]
      connect_bd_net [get_bd_pins $core/gt_txusrclk2] [get_bd_pins $core/rx_clk]

      connect_bd_net [get_bd_pins $core/gt_txusrclk2] [get_bd_pins /Network/sfp_tx_clock_${name}]
      connect_bd_net [get_bd_pins $core/gt_txusrclk2] [get_bd_pins /Network/sfp_rx_clock_${name}]

      set out_inv [create_inverter tx_reset_inverter_${name}]
      connect_bd_net [get_bd_pins $core/usr_tx_reset] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_tx_resetn_${name}] [get_bd_pins $out_inv/Res]

      set out_inv [create_inverter rx_reset_inverter_${name}]
      connect_bd_net [get_bd_pins $core/usr_rx_reset] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_rx_resetn_${name}] [get_bd_pins $out_inv/Res]

      connect_bd_net [get_bd_pins dclk_reset/peripheral_aresetn] $port_qsfp_rst

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