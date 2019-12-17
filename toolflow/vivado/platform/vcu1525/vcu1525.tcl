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
# @file		vcu1525.tcl
# @brief	VCU1525 platform implementation.
# @author	J. A. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
#
namespace eval platform {
  set platform_dirname "vcu1525"
  variable pcie_width "x16"

  source $::env(TAPASCO_HOME_TCL)/platform/pcie/pcie_base.tcl

  proc create_mig_core {name} {
    puts "Creating MIG core for DDR ..."
    set s_axi_host [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_CTRL"]

    set mig [tapasco::ip::create_us_ddr ${name}]
    apply_board_connection -board_interface "ddr4_sdram_c0" -ip_intf "$name/C0_DDR4" -diagram "system"
    apply_board_connection -board_interface "default_300mhz_clk0" -ip_intf "$name/C0_SYS_CLK" -diagram "system"
    apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface "resetn ( FPGA Resetn ) " }  [get_bd_pins $name/sys_rst]

    delete_bd_objs [get_bd_nets resetn_1]
    set rst_inv [tapasco::ip::create_logic_vector "rst_inv_ddr_in"]
    set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] $rst_inv
    connect_bd_net [get_bd_pins $rst_inv/Res] [get_bd_pins $name/sys_rst]
    connect_bd_net [get_bd_pins resetn] [get_bd_pins $rst_inv/Op1]

    connect_bd_intf_net [get_bd_intf_pins ${name}/C0_DDR4_S_AXI_CTRL] $s_axi_host

    set inst [current_bd_instance -quiet .]
    current_bd_instance -quiet

    set m_si [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 host/M_MEM_CTRL]

    set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells host/out_ic]]
    set num_mi [expr "$num_mi_old + 1"]
    set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells host/out_ic]
    connect_bd_intf_net $m_si [get_bd_intf_pins host/out_ic/[format "M%02d_AXI" $num_mi_old]]

    current_bd_instance -quiet $inst

    return $mig
  }

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."

    # create PCIe core
    set axi_pcie3_0 [tapasco::ip::create_axi_pcie3_0_usp "axi_pcie3_0"]

    apply_board_connection -board_interface "pci_express_x16" -ip_intf "${axi_pcie3_0}/pcie_mgt" -diagram "system"
    apply_board_connection -board_interface "pcie_perstn" -ip_intf "${axi_pcie3_0}/RST.sys_rst_n" -diagram "system"

    apply_bd_automation -rule xilinx.com:bd_rule:xdma -config {auto_level "IP Level" lane_width "X16" link_speed "8.0 GT/s (PCIe Gen 3)" axi_clk "Maximum Data Width" axi_intf "AXI Memory Mapped" bar_size "Disable" bypass_size "Disable" h2c "4" c2h "4" }  ${axi_pcie3_0}

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

    tapasco::ip::create_msixusptrans "MSIxTranslator" $axi_pcie3_0

    return $axi_pcie3_0
  }

    namespace eval vcu1525 {
        namespace export addressmap

        proc addressmap {args} {
            set args [lappend args "M_MEM_CTRL" [list 0x40000 0 0 ""]]
            return $args
        }
    }


    tapasco::register_plugin "platform::vcu1525::addressmap" "post-address-map"
}
