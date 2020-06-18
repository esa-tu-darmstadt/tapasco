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

namespace eval platform {
  set platform_dirname "AU50"
  variable pcie_width "x16"
  variable device_type "US+"

  if { [::tapasco::vivado_is_newer "2019.2"] == 0 } {
    # Vivado 2019.1 has only U50dd in XilinxBoardStore
    puts "Vivado [version -short] is too old to support AU50."
    exit 1
  }

  source $::env(TAPASCO_HOME_TCL)/platform/pcie/pcie_base.tcl

  proc create_mig_core {name} {
    puts "Does not have DDR ..."
    puts "Creating dummy, BRAM-based memory"

    set instance [current_bd_instance .]
    set cell [create_bd_cell -type hier ${instance}/$name]
    current_bd_instance $cell

    set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI"]
    set ui_clk [create_bd_pin -type "clk" -dir "O" "ui_clk"]
    set mmcm_locked [create_bd_pin -dir "O" "mmcm_locked"]
    set ui_clk_sync_rst [create_bd_pin -type "reset" -dir "O" "ui_clk_sync_rst"]

    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 mig
    set_property -dict [list CONFIG.DATA_WIDTH {512} CONFIG.SINGLE_PORT_BRAM {1} CONFIG.ECC_TYPE {0}] [get_bd_cells mig]
    apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins mig/BRAM_PORTA]

    tapasco::ip::create_clk_wiz clk_wiz_0
    set_property -dict [list CONFIG.CLK_OUT1_PORT {ui_clk} \
                        CONFIG.USE_SAFE_CLOCK_STARTUP {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [tapasco::get_mem_frequency] \
                        CONFIG.USE_LOCKED {true} \
                        CONFIG.USE_RESET {false}] [get_bd_cells clk_wiz_0]

    connect_bd_intf_net [get_bd_intf_pins mig/S_AXI] $s_axi
    connect_bd_net [get_bd_pins clk_wiz_0/ui_clk] $ui_clk
    connect_bd_net [get_bd_pins clk_wiz_0/ui_clk] [get_bd_pins mig/s_axi_aclk]
    connect_bd_net [get_bd_pins clk_wiz_0/locked] $mmcm_locked
    connect_bd_net [get_bd_pins mig/s_axi_aresetn] $ui_clk_sync_rst
    connect_bd_net [get_bd_pins mig/s_axi_aresetn] $mmcm_locked

    # exit the hierarchical group
    current_bd_instance $instance

    connect_bd_net [get_bd_pins host_clk] [get_bd_pins ${name}/clk_wiz_0/clk_in1]
    return $cell

  }

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."

    # create PCIe core
    set pcie_core [tapasco::ip::create_axi_pcie3_0_usp "axi_pcie3_0"]

    apply_bd_automation -rule xilinx.com:bd_rule:xdma -config { accel {1} auto_level {IP Level} axi_clk {Maximum Data Width} axi_intf {AXI Memory Mapped} bar_size {Disable} bypass_size {Disable} c2h {4} cache_size {32k} h2c {4} lane_width {X16} link_speed {8.0 GT/s (PCIe Gen 3)}}  [get_bd_cells $pcie_core]

    set pcie_properties [list \
      CONFIG.functional_mode {AXI_Bridge} \
      CONFIG.mode_selection {Advanced} \
      CONFIG.pcie_blk_locn {PCIE4C_X1Y1} \
      CONFIG.pl_link_cap_max_link_width {X16} \
      CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
      CONFIG.axi_addr_width {64} \
      CONFIG.pipe_sim {true} \
      CONFIG.pf0_revision_id {01} \
      CONFIG.pf0_base_class_menu {Memory_controller} \
      CONFIG.pf0_sub_class_interface_menu {Other_memory_controller} \
      CONFIG.pf0_interrupt_pin {NONE} \
      CONFIG.pf0_msi_enabled {false} \
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

    if {[catch {set_property -dict $pcie_properties $pcie_core}]} {
        error "ERROR: Failed to configure PCIe bridge. For Vivado 2019.2, please install patch from Xilinx AR# 73001."
    }

    tapasco::ip::create_msixusptrans "MSIxTranslator" $pcie_core

    return $pcie_core
  }
}
