#
# Copyright (C) 2018 Jaco A. Hofmann, TU Darmstadt
#
# This file is part of Tapasco (TPC).
#
# Tapasco is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Tapasco is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
#
# @file		vc709.tcl
# @brief	VC709 platform implementation.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
# @author	J. A. Hofmann, TU Darmstadt (jah@esa.tu-darmstadt.de)
#
namespace eval platform {

  set platform_dirname "vcu108"

  source $::env(TAPASCO_HOME)/platform/pcie/pcie_base.tcl

  proc create_mig_core {name} {
    puts "Creating MIG core for DDR ..."
    # create ports
    set mig [tapasco::ip::create_us_ddr ${name}]
    apply_board_connection -board_interface "ddr4_sdram_c1" -ip_intf "$mig/C0_DDR4" -diagram "system"
    apply_board_connection -board_interface "reset" -ip_intf "$mig/SYSTEM_RESET" -diagram "system"
    set_property -dict [list CONFIG.System_Clock {Differential}] $mig
    apply_board_connection -board_interface "default_sysclk1_300" -ip_intf "$mig/C0_SYS_CLK" -diagram "system"

    save_bd_design

    return $mig
  }

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."
    # create ports
    set axi_pcie3_0 [tapasco::ip::create_axi_pcie3_0 "axi_pcie3_0"]

    set pcie_properties [list \
      CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
      CONFIG.PCIE_BOARD_INTERFACE {pci_express_x8} \
      CONFIG.axi_data_width {256_bit} \
      CONFIG.pcie_blk_locn {X0Y0} \
      CONFIG.pf0_bar0_64bit {true} \
      CONFIG.pf0_bar0_scale {Megabytes} \
      CONFIG.pf0_bar0_size {64} \
      CONFIG.pf0_device_id {7038} \
      CONFIG.pl_link_cap_max_link_width {X8} \
      CONFIG.pipe_sim {true} \
      CONFIG.comp_timeout {50ms} \
      CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
      CONFIG.axisten_freq {250} \
      CONFIG.axi_addr_width {64} \
      CONFIG.pf0_msi_enabled {false} \
      CONFIG.pf0_msix_enabled {true} \
      CONFIG.pf0_msix_cap_table_size {83} \
      CONFIG.pf0_msix_cap_table_offset {500000} \
      CONFIG.pf0_msix_cap_pba_offset {508000} \
      CONFIG.comp_timeout {50ms} \
      CONFIG.pf0_interrupt_pin {NONE} \
      CONFIG.c_s_axi_supports_narrow_burst {false} \
    ]

    # enable ATS/PRI (if platform feature is set)
    if {[tapasco::is_feature_enabled "ATS-PRI"]} {
      puts "  ATS/PRI support is enabled"
      lappend pcie_properties \
        CONFIG.c_ats_enable {true} \
        CONFIG.c_pri_enable {true} \
    }
    set_property -dict $pcie_properties $axi_pcie3_0

    apply_bd_automation -rule xilinx.com:bd_rule:axi_pcie3 -config {lane_width "X8" link_speed "8.0 GT/s (PCIe Gen 3)" axi_clk "Maximum Data Width" } $axi_pcie3_0

    return $axi_pcie3_0
  }
}
