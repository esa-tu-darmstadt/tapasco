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

  proc is_svm_supported {} {
    return true
  }

  proc customize_100g_core {eth_core mac_addr} {
    set_property -dict [list \
      CONFIG.CMAC_CAUI4_MODE {1} \
      CONFIG.NUM_LANES {4x25} \
      CONFIG.USER_INTERFACE {AXIS} \
      CONFIG.GT_REF_CLK_FREQ {156.25} \
      CONFIG.TX_FLOW_CONTROL {1} \
      CONFIG.RX_FLOW_CONTROL {1} \
      CONFIG.TX_SA_GPP $mac_addr \
      CONFIG.TX_SA_PPP $mac_addr \
      CONFIG.INCLUDE_RS_FEC {1} \
      CONFIG.ENABLE_AXI_INTERFACE {0} \
      CONFIG.INCLUDE_STATISTICS_COUNTERS {0} \
      CONFIG.RX_MAX_PACKET_LEN {16383} \
      CONFIG.CMAC_CORE_SELECT {CMACE4_X0Y6} \
      CONFIG.GT_GROUP_SELECT {X0Y40~X0Y43} \
    ] $eth_core
  }

  proc customize_stream_regslices {tx_rs rx_rs} {
    set_property -dict [list \
      CONFIG.REG_CONFIG {15} \
      CONFIG.NUM_SLR_CROSSINGS {1} \
      CONFIG.PIPELINES_MASTER {4} \
      CONFIG.PIPELINES_SLAVE {4} \
    ] $tx_rs
    set_property -dict [list \
      CONFIG.REG_CONFIG {15} \
      CONFIG.NUM_SLR_CROSSINGS {1} \
      CONFIG.PIPELINES_MASTER {4} \
      CONFIG.PIPELINES_SLAVE {4} \
    ] $rx_rs
  }

  proc set_custom_constraints {constraints_file} {
    puts $constraints_file [format {set_property PACKAGE_PIN T42 [get_ports qsfp0_156mhz_svm_clk_p]}]
  }

  proc create_custom_interfaces {eth_core const_zero_core const_one_core clk_reset_core} {
    set gt_refclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 qsfp0_156mhz_svm]
    set_property CONFIG.FREQ_HZ 156250000 $gt_refclk
    connect_bd_intf_net $gt_refclk [get_bd_intf_pins $eth_core/gt_ref_clk]
    make_bd_intf_pins_external [get_bd_intf_pins $eth_core/gt_serial_port]
  }
}
