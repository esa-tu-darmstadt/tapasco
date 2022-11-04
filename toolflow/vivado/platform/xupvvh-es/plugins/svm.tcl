# Copyright (c) 2014-2022 Embedded Systems and Applications, TU Darmstadt.
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

namespace eval svm {

  variable refclk_pins           {"P13" "V13" "AD13" "AJ15"}
  variable cmac_cores            {"CMACE4_X0Y7" "CMACE4_X0Y6" "CMACE4_X0Y4" "CMACE4_X0Y2"}
  variable gt_groups             {"X1Y44~X1Y47" "X1Y36~X1Y39" "X1Y24~X1Y27" "X1Y16~X1Y19"}
  variable qsfp_rst              {"A21" "A19" "B16" "C19"}

  proc is_svm_supported {} {
    return true
  }

  proc is_network_port_valid {port_no} {
    if {$port_no < 4} {
      return true
    }
    return false
  }

  proc customize_100g_core {eth_core mac_addr port_no} {
    variable cmac_cores
    variable gt_groups

    set_property -dict [list \
      CONFIG.CMAC_CAUI4_MODE {1} \
      CONFIG.NUM_LANES {4x25} \
      CONFIG.USER_INTERFACE {AXIS} \
      CONFIG.GT_REF_CLK_FREQ {322.265625} \
      CONFIG.TX_FLOW_CONTROL {1} \
      CONFIG.RX_FLOW_CONTROL {1} \
      CONFIG.TX_SA_GPP $mac_addr \
      CONFIG.TX_SA_PPP $mac_addr \
      CONFIG.INCLUDE_RS_FEC {1} \
      CONFIG.ENABLE_AXI_INTERFACE {0} \
      CONFIG.INCLUDE_STATISTICS_COUNTERS {0} \
      CONFIG.RX_MAX_PACKET_LEN {16383} \
      CONFIG.CMAC_CORE_SELECT [lindex $cmac_cores $port_no] \
      CONFIG.GT_GROUP_SELECT [lindex $gt_groups $port_no] \
    ] $eth_core
  }

  proc set_custom_constraints {constraints_file port_no} {
    variable refclk_pins
    variable qsfp_rst

    puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports qsfp0_322mhz_svm_clk_p]} [lindex $refclk_pins $port_no]]
    puts $constraints_file {set_property PACKAGE_PIN E17 [get_ports fpga_i2c_master_svm]}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports fpga_i2c_master_svm]}
    puts $constraints_file {set_property PACKAGE_PIN C18 [get_ports qsfp_ctl_en_svm]}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports qsfp_ctl_en_svm]}
    puts $constraints_file {set_property PACKAGE_PIN B18 [get_ports qsfp_lp_svm]}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports qsfp_lp_svm]}
    puts $constraints_file [format {set_property PACKAGE_PIN %s [get_ports qsfp_rst_l_svm]} [lindex $qsfp_rst $port_no]]
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports qsfp_rst_l_svm]}
  }

  proc create_custom_interfaces {eth_core const_zero_core const_one_core clk_reset_core} {
    set gt_refclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 qsfp0_322mhz_svm]
    set_property CONFIG.FREQ_HZ 322265625 $gt_refclk
    set fpga_i2c_master [create_bd_port -dir O fpga_i2c_master_svm]
    set qsfp_ctl_en [create_bd_port -dir O qsfp_ctl_en_svm]
    set qsfp_lp [create_bd_port -dir O qsfp_lp_svm]
    set qsfp_rst_l [create_bd_port -dir O qsfp_rst_l_svm]

    connect_bd_intf_net $gt_refclk [get_bd_intf_pins $eth_core/gt_ref_clk]
    connect_bd_net [get_bd_pins $const_zero_core/dout] $fpga_i2c_master $qsfp_lp
    connect_bd_net [get_bd_pins $const_one_core/dout] $qsfp_ctl_en
    connect_bd_net [get_bd_pins $clk_reset_core/peripheral_aresetn] $qsfp_rst_l
    make_bd_intf_pins_external [get_bd_intf_pins $eth_core/gt_rx]
    make_bd_intf_pins_external [get_bd_intf_pins $eth_core/gt_tx]
  }
}
