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
  set pcie_width "x16"

  if { [::tapasco::vivado_is_newer "2020.1"] == 0 } {
    puts "Vivado [version -short] is too old to support AU50."
    exit 1
  }

  source $::env(TAPASCO_HOME_TCL)/platform/pcie/pcie_base.tcl

    proc get_ignored_segments { } {
      set ignored [list]
      set axi_index "23"
      for {set j 0} {$j < 32} {incr j} {
        set mem_index [format %02s $j]
        lappend ignored "/memory/mig/mig_internal/SAXI_${axi_index}/HBM_MEM${mem_index}"
      }
      return $ignored
    }

    proc set_addressmap_AU50 {{args {}}} {
	    for {set i 0} {$i < 32} {incr i} {
		    assign_bd_address [get_bd_addr_segs memory/mig/mig_internal/SAXI_23/HBM_MEM[format %02s $i]]
	    }
	    return $args
    }

  proc create_mig_core {name} {
    puts "Creating HBM controllers ..."

    set old_inst [current_bd_instance .]
    set mig [create_bd_cell -type hier ${name}]
    current_bd_instance $mig   


    set hbm [tapasco::ip::create_hbm_controller ${name}_internal]

set hbm_properties [list \
      CONFIG.USER_APB_EN {false} \
      CONFIG.USER_SWITCH_ENABLE_00 {true} \
      CONFIG.USER_SWITCH_ENABLE_01 {true} \
      CONFIG.USER_AXI_INPUT_CLK_FREQ [tapasco::get_mem_frequency] \
      CONFIG.USER_XSDB_INTF_EN {TRUE} \
      CONFIG.USER_HBM_DENSITY {8GB} \
]

for {set i 0} {$i < 32} {incr i} {
    set saxi [format %02s $i]
    if {$i != 23} {
        lappend hbm_properties CONFIG.USER_SAXI_${saxi} {false}
    }
}

for {set i 0} {$i < 32} {incr i} {
    if [expr {($i %2) == 0}] {
        set mc [format %s [expr {$i / 2}]]
        lappend hbm_properties CONFIG.USER_MC${mc}_ECC_BYPASS true
        lappend hbm_properties CONFIG.USER_MC${mc}_ECC_CORRECTION false
        lappend hbm_properties CONFIG.USER_MC${mc}_EN_DATA_MASK true
        lappend hbm_properties CONFIG.USER_MC${mc}_TRAFFIC_OPTION {Linear}
        lappend hbm_properties CONFIG.USER_MC${mc}_BG_INTERLEAVE_EN true
    }
}

set_property -dict $hbm_properties $hbm

set hbm_clk_buf [tapasco::ip::create_util_buf hbm_clk_buf]
    apply_board_connection -board_interface "hbm_clk" -ip_intf "${hbm_clk_buf}/CLK_IN_D" -diagram "system"
    connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins ${hbm}/HBM_REF_CLK_0]
    connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins ${hbm}/HBM_REF_CLK_1]


set memory_clk_wiz [tapasco::ip::create_clk_wiz memory_clk_wiz]
set_property -dict [list CONFIG.CLK_OUT1_PORT {memory_clk} \
                        CONFIG.USE_SAFE_CLOCK_STARTUP {false} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [tapasco::get_mem_frequency] \
                        CONFIG.USE_LOCKED {true} \
                        CONFIG.USE_RESET {false}] $memory_clk_wiz


set rst_gen [tapasco::ip::create_rst_gen "apb_rst_gen"]
connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins $hbm/APB_0_PCLK]
connect_bd_net [get_bd_pins $rst_gen/peripheral_aresetn] [get_bd_pins $hbm/APB_0_PRESET_N]
connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins $hbm/APB_1_PCLK]
connect_bd_net [get_bd_pins $rst_gen/peripheral_aresetn] [get_bd_pins $hbm/APB_1_PRESET_N]
connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins $rst_gen/slowest_sync_clk]
connect_bd_net [get_bd_pins ${old_inst}/host_peripheral_areset] [get_bd_pins ${rst_gen}/ext_reset_in]


set rst_gen [tapasco::ip::create_rst_gen "mem_rst_gen"]

connect_bd_net [get_bd_pins $memory_clk_wiz/memory_clk] [get_bd_pins $rst_gen/slowest_sync_clk]
connect_bd_net [get_bd_pins $memory_clk_wiz/locked] [get_bd_pins $rst_gen/dcm_locked]
connect_bd_net [get_bd_pins $memory_clk_wiz/memory_clk] [get_bd_pins $hbm/AXI_23_ACLK]
connect_bd_net [get_bd_pins $rst_gen/peripheral_aresetn] [get_bd_pins $hbm/AXI_23_ARESET_N]
connect_bd_net [get_bd_pins $memory_clk_wiz/clk_in1] [get_bd_pins $hbm_clk_buf/IBUF_OUT]
connect_bd_net [get_bd_pins ${old_inst}/host_peripheral_areset] [get_bd_pins ${rst_gen}/ext_reset_in]

set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI]
connect_bd_intf_net [get_bd_intf_pins $hbm/SAXI_23] $s_axi
set ui_rst [create_bd_pin -dir O ui_clk_sync_rst]
connect_bd_net $ui_rst [get_bd_pins $rst_gen/peripheral_aresetn]
set lock [create_bd_pin -dir O mmcm_locked]
connect_bd_net $lock [get_bd_pins $memory_clk_wiz/locked]
set ui_clk [create_bd_pin -dir O ui_clk]
connect_bd_net $ui_clk [get_bd_pins $memory_clk_wiz/memory_clk]




  set constraints_fn "[get_property DIRECTORY [current_project]]/hbm_debug.xdc"
  set constraints_file [open $constraints_fn w+]
  puts $constraints_file {connect_debug_port dbg_hub/clk [get_nets system_i/memory/mig/hbm_clk_buf/IBUF_OUT*]}
  puts $constraints_file {set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]}
  close $constraints_file
  read_xdc $constraints_fn
  set_property PROCESSING_ORDER NORMAL [get_files $constraints_fn]

  current_bd_instance ${old_inst}

    return $mig
  }
  

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."

    set pcie_core [tapasco::ip::create_axi_pcie3_0_usp axi_pcie3_0]

    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {pci_express_x16 ( PCI Express ) } Manual_Source {Auto}}  [get_bd_intf_pins $pcie_core/pcie_mgt]
    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {pcie_perstn ( PCI Express ) } Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins $pcie_core/sys_rst_n]

    apply_bd_automation -rule xilinx.com:bd_rule:xdma -config { accel {1} auto_level {IP Level} axi_clk {Maximum Data Width} axi_intf {AXI Memory Mapped} bar_size {Disable} bypass_size {Disable} c2h {4} cache_size {32k} h2c {4} lane_width {X16} link_speed {8.0 GT/s (PCIe Gen 3)}}  [get_bd_cells $pcie_core]

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
      error "ERROR: Failed to configure PCIe bridge. This may be related to the format settings of your OS for numbers. Please check that it is set to 'United States' (see AR# 51331)"
    }
    set_property -dict $pcie_properties $pcie_core


    tapasco::ip::create_msixusptrans "MSIxTranslator" $pcie_core

    return $pcie_core
  }

  tapasco::register_plugin "platform::set_addressmap_AU50" "post-address-map"

}
