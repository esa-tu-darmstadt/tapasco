#
# Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
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
# @file		vcu118.tcl
# @brief	VCU118 platform implementation.
# @author	J. A. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
#
namespace eval platform {
  set platform_dirname "vcu118"
  set pcie_width "x16"

  source $::env(TAPASCO_HOME_TCL)/platform/pcie/pcie_base.tcl

  proc create_mig_core {name} {
    puts "Creating MIG core for DDR ..."
    set mig [tapasco::ip::create_us_ddr ${name}]
    apply_board_connection -board_interface "ddr4_sdram_c1" -ip_intf "$name/C0_DDR4" -diagram "system"
    apply_board_connection -board_interface "default_250mhz_clk1" -ip_intf "$name/C0_SYS_CLK" -diagram "system"
    apply_board_connection -board_interface "reset" -ip_intf "$name/SYSTEM_RESET" -diagram "system"
    return $mig
  }

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."

    # create PCIe core
    set axi_pcie3_0 [tapasco::ip::create_axi_pcie3_0_usp "axi_pcie3_0"]

    set pcie_properties [list \
      CONFIG.functional_mode {AXI_Bridge} \
      CONFIG.mode_selection {Advanced} \
      CONFIG.pl_link_cap_max_link_width {X16} \
      CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
      CONFIG.axi_addr_width {64} \
      CONFIG.pipe_sim {true} \
      CONFIG.pf0_revision_id {01} \
      CONFIG.pf0_base_class_menu {Memory_controller} \
      CONFIG.pf0_sub_class_interface_menu {Other_memory_controller} \
      CONFIG.pf0_interrupt_pin {NONE} CONFIG.pf0_msi_enabled {false} \
      CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
      CONFIG.PCIE_BOARD_INTERFACE {pci_express_x16} \
      CONFIG.pf0_msix_enabled {true} \
      CONFIG.c_m_axi_num_write {32} \
      CONFIG.pf0_msix_impl_locn {External} \
      CONFIG.pf0_bar0_size {64} \
      CONFIG.pf0_bar0_scale {Megabytes} \
      CONFIG.pf0_bar0_64bit {true} \
      CONFIG.axi_data_width {512_bit} \
      CONFIG.pf0_device_id {7038} \
      CONFIG.pf0_class_code_base {05} \
      CONFIG.pf0_class_code_sub {80} \
      CONFIG.pf0_class_code_interface {00} \
      CONFIG.xdma_axilite_slave {true} \
      CONFIG.coreclk_freq {500} \
      CONFIG.plltype {QPLL1} \
      CONFIG.pf0_msix_cap_table_size {83} \
      CONFIG.pf0_msix_cap_table_offset {20000} \
      CONFIG.pf0_msix_cap_table_bir {BAR_1:0} \
      CONFIG.pf0_msix_cap_pba_offset {28000} \
      CONFIG.pf0_msix_cap_pba_bir {BAR_1:0} \
      CONFIG.bar_indicator {BAR_1:0} \
      CONFIG.bar0_indicator {0}
      ]

    if {[catch {set_property -dict $pcie_properties $axi_pcie3_0}]} {
        error "ERROR: Failed to configure PCIe bridge. For Vivado 2019.2, please install patch from Xilinx AR# 73001."
    }

    apply_bd_automation -rule xilinx.com:bd_rule:xdma \
      -config {auto_level "IP Level" \
               lane_width "X16" \
               link_speed "8.0 GT/s (PCIe Gen 3)" \
               axi_clk "Maximum Data Width" \
               axi_intf "AXI Memory Mapped" \
               bar_size "Disable" \
               bypass_size "Disable" \
               h2c "4" c2h "4" }  \
               $axi_pcie3_0


    tapasco::ip::create_msixusptrans "MSIxTranslator" $axi_pcie3_0

    return $axi_pcie3_0
  }
}
