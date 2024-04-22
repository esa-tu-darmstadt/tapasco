# Copyright (c) 2014-2024 Embedded Systems and Applications, TU Darmstadt.
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
  set platform_dirname "vck5000"
  set pcie_width "8"
  set pcie_speed "16.0"

  source $::env(TAPASCO_HOME_TCL)/platform/versal/versal_base.tcl

  proc get_number_mc {} {
    return 4
  }

  proc get_mc_config {} {
    return [list \
      CONFIG.MC_INPUT_FREQUENCY0 {200.000} \
      CONFIG.MC_INPUTCLK0_PERIOD {5000} \
      CONFIG.MC_MEMORY_SPEEDGRADE {DDR4-3200AA(22-22-22)} \
      CONFIG.MC_COMPONENT_WIDTH {x16} \
      CONFIG.MC_MEM_DEVICE_WIDTH {x16} \
      CONFIG.MC_COMPONENT_DENSITY {16Gb} \
      CONFIG.MC_MEMORY_DENSITY {8GB} \
      CONFIG.MC_MEMORY_DEVICE_DENSITY {16Gb} \
      CONFIG.MC_TFAW {30000} \
      CONFIG.MC_TRCD {13750} \
      CONFIG.MC_TRFC {550000} \
      CONFIG.MC_TRP {13750} \
      CONFIG.MC_TRRD_S {9} \
      CONFIG.MC_TRRD_L {11} \
      CONFIG.MC_TXPR {896} \
      CONFIG.MC_ROWADDRESSWIDTH {17} \
      CONFIG.MC_BG_WIDTH {1} \
      CONFIG.MC_CASLATENCY {22} \
      CONFIG.MC_CASWRITELATENCY {16} \
      CONFIG.MC_TRC {45750} \
      CONFIG.MC_USER_DEFINED_ADDRESS_MAP {17RA-2BA-1BG-10CA} \
      CONFIG.MC_TFAWMIN {30000} \
      CONFIG.MC_TRPMIN {13750} \
      CONFIG.MC_TRRD_S_MIN {9} \
      CONFIG.MC_TRFCMIN {550000} \
      CONFIG.MC_EN_INTR_RESP {FALSE} \
      CONFIG.MC_F1_TFAW {30000} \
      CONFIG.MC_F1_TFAWMIN {30000} \
      CONFIG.MC_F1_TRRD_S {9} \
      CONFIG.MC_F1_TRRD_S_MIN {9} \
      CONFIG.MC_F1_TRRD_L {11} \
      CONFIG.MC_F1_TRRD_L_MIN {11} \
      CONFIG.MC_F1_TRCD {13750} \
      CONFIG.MC_F1_TRCDMIN {13750} \
      CONFIG.MC_F1_LPDDR4_MR1 {0x000} \
      CONFIG.MC_F1_LPDDR4_MR2 {0x000} \
      CONFIG.MC_F1_LPDDR4_MR3 {0x000} \
      CONFIG.MC_F1_LPDDR4_MR13 {0x000} \
      CONFIG.MC_DATAWIDTH {72} \
      CONFIG.MC_DQ_WIDTH {72} \
      CONFIG.MC_DQS_WIDTH {9} \
      CONFIG.MC_DM_WIDTH {9} \
      CONFIG.MC_EN_ECC_SCRUBBING {true} \
      CONFIG.MC_INIT_MEM_USING_ECC_SCRUB {true} \
      CONFIG.MC_ECC {true} \
      CONFIG.MC_ECC_SCRUB_SIZE {8192} \
      CONFIG.MC_INTERLEAVE_SIZE {4096} \
      CONFIG.MC_DDR_INIT_TIMEOUT {0x00079C3E}]
  }

  proc get_cips_config {} {
    # MIO44 and MIO49 disable lpmode for qsfp28 transceiver
    return [list \
      CONFIG.PS_PMC_CONFIG { \
        PMC_BANK_1_IO_STANDARD LVCMOS3.3 \
        PS_BANK_2_IO_STANDARD LVCMOS3.3 \
        PMC_MIO12 {{DIRECTION out} {USAGE GPIO}} \
        PMC_MIO44 {{DIRECTION out} {OUTPUT_DATA low} {PULL pullup} {USAGE GPIO}} \
        PMC_MIO49 {{DIRECTION out} {OUTPUT_DATA low} {PULL pullup} {USAGE GPIO}} \
        PS_MIO5 {{DIRECTION out} {OUTPUT_DATA high} {USAGE GPIO}} \
        PS_MIO6 {{USAGE GPIO}} \
        PMC_CRP_OSPI_REF_CTRL_FREQMHZ 135 \
        PMC_CRP_LSBUS_REF_CTRL_FREQMHZ 150 \
        PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE {Dual Stacked}}} \
        SMON_INTERFACE_TO_USE I2C \
        PS_I2CSYSMON_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 18 .. 19}}} \
        PMC_I2CPMC_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 27}}} \
        PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 30 .. 31}}}  PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
        PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 16 .. 17}}}  PS_UART1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 20 .. 21}}} \
        PS_TTC0_PERIPHERAL_ENABLE 1 \
        PMC_MIO_EN_FOR_PL_PCIE 1 PS_PCIE_EP_RESET1_IO {PMC_MIO 38} PS_PCIE_EP_RESET2_IO {PMC_MIO 39} PS_PCIE_RESET {{ENABLE 1}} \
      } \
    ]
  }

  proc get_mc_clk_freq {} {
    return 200000000
  }

  proc get_total_memory_size {} {
    return [expr "1 << 34"]
  }

  proc add_constraints {args} {
    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/vck5000/vck5000.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
    return $args
  }

  tapasco::register_plugin "platform::add_constraints" "post-platform"
}
