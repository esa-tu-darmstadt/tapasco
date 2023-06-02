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

namespace eval platform {
  set platform_dirname "HAWK"
  set pcie_width "8"

  if {[version -short] != "2021.2"} {
    puts "Vivado [version -short] is not supported for this Versal ES device."
    exit 1
  }

  source $::env(TAPASCO_HOME_TCL)/platform/versal/versal_base.tcl

  # give configuration for NoC MCs
  proc get_number_mc {} {
    return 4
  }

  proc get_mc_config {} {
    return [list CONFIG.CONTROLLERTYPE {DDR4_SDRAM} \
      CONFIG.MC0_CONFIG_NUM {config17} \
      CONFIG.MC1_CONFIG_NUM {config17} \
      CONFIG.MC2_CONFIG_NUM {config17} \
      CONFIG.MC3_CONFIG_NUM {config17} \
      CONFIG.MC_CASLATENCY {15} \
      CONFIG.MC_CASWRITELATENCY {11} \
      CONFIG.MC_CA_MIRROR {true} \
      CONFIG.MC_COMPONENT_DENSITY {16Gb} \
      CONFIG.MC_CONFIG_NUM {config17} \
      CONFIG.MC_CS_WIDTH {2} \
      CONFIG.MC_DDR4_2T {Disable} \
      CONFIG.MC_DDR_INIT_TIMEOUT {0x002E3BF0} \
      CONFIG.MC_ECC_SCRUB_PERIOD {0x002710} \
      CONFIG.MC_ECC_SCRUB_SIZE {32768} \
      CONFIG.MC_F1_CASLATENCY {22} \
      CONFIG.MC_F1_LPDDR4_MR1 {0x0000} \
      CONFIG.MC_F1_LPDDR4_MR2 {0x0000} \
      CONFIG.MC_F1_LPDDR4_MR3 {0x0000} \
      CONFIG.MC_F1_LPDDR4_MR13 {0x0000} \
      CONFIG.MC_F1_TRCD {12960} \
      CONFIG.MC_F1_TRCDMIN {12960} \
      CONFIG.MC_INPUTCLK0_PERIOD {10000} \
      CONFIG.MC_INPUT_FREQUENCY0 {100.000} \
      CONFIG.MC_MEMORY_DENSITY {32GB} \
      CONFIG.MC_MEMORY_DEVICETYPE {SODIMMs} \
      CONFIG.MC_MEMORY_DEVICE_DENSITY {16Gb} \
      CONFIG.MC_MEMORY_SPEEDGRADE {DDR4-2933V(19-19-19)} \
      CONFIG.MC_MEMORY_TIMEPERIOD0 {1000} \
      CONFIG.MC_MEMORY_TIMEPERIOD1 {690} \
      CONFIG.MC_RANK {2} \
      CONFIG.MC_ROWADDRESSWIDTH {17} \
      CONFIG.MC_TCCD_L {5} \
      CONFIG.MC_TCKE {5} \
      CONFIG.MC_TCKEMIN {5} \
      CONFIG.MC_TPAR_ALERT_ON {6} \
      CONFIG.MC_TPAR_ALERT_PW_MAX {128} \
      CONFIG.MC_TRC {44960} \
      CONFIG.MC_TRCD {12960} \
      CONFIG.MC_TRFC {550000} \
      CONFIG.MC_TRFCMIN {550000} \
      CONFIG.MC_TRP {12960} \
      CONFIG.MC_TRPMIN {12960} \
      CONFIG.MC_TRRD_L {5} \
      CONFIG.MC_TRTP_nCK {8} \
      CONFIG.MC_TXP {6} \
      CONFIG.MC_TXPMIN {6} \
      CONFIG.MC_TXPR {560} \
      CONFIG.MC_USER_DEFINED_ADDRESS_MAP {1CS-17RA-2BA-2BG-10CA} \
      CONFIG.MC_XPLL_CLKOUT1_PERIOD {2000} \
      CONFIG.MC_XPLL_DIV4_CLKOUT12 {FALSE}]
  }

  proc get_mc_clk_freq {} {
    return 100000000
  }

  proc get_total_memory_size {} {
    return [expr "1 << 37"]
  }

  # give PCIe configuration
  # TODO

  proc add_constraints {args} {
    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/HAWK/hawk.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
    return $args
  }

  tapasco::register_plugin "platform::add_constraints" "post-platform"
}
