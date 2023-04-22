# Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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

  # distribute 128 PEs over 31 AXIs
  proc max_masters {} {
    set masters [list]
    for {set i 0} {$i < 31} {incr i} {
      if {$i < 4} {
        set masters [lappend masters 5]
      } else {
        set masters [lappend masters 4]
      }
    }
    return $masters
  }

  # put HBM segments on ignore list and assign them manually
  if {![tapasco::is_feature_enabled "SVM"]} {
    proc get_ignored_segments {} {
      puts "Running get_ignored_segments from AU50"
      set num_masters [llength [::arch::get_masters]]
      set ignored [list]
      for {set i 0} {$i < 32} {incr i} {
        set axi_index [format %02s $i]
        if {$i < $num_masters || $i == 31} {
          for {set j 0} {$j < 32} {incr j} {
            set mem_index [format %02s $j]
            lappend ignored "/memory/hbm_0/SAXI_${axi_index}/HBM_MEM${mem_index}"
          }
        }
      }
      return $ignored
    }

    proc set_addressmap_AU50 {{args {}}} {
      set num_masters [llength [::arch::get_masters]]
      for {set i 0} {$i < 32} {incr i} {
        set axi_index [format %02s $i]
        if {$i < $num_masters || $i == 31} {
          for {set j 0} {$j < 32} {incr j} {
            set mem_index [format %02s $j]
            assign_bd_address [get_bd_addr_segs memory/hbm_0/SAXI_${axi_index}/HBM_MEM${mem_index}]
          }
        }
      }

      # add additional PE masters to address map
      for {set i 1} {$i < $num_masters} {incr i} {
        set name "M_MEM_$i"
        set args [lappend args $name [list 0 0 0 ""]]
      }
      return $args
    }
  }

  proc create_subsystem_memory {} {
    save_bd_design
    set num_masters [llength [::arch::get_masters]]

    # create hierarchical interface ports
    for {set i 0} {$i < $num_masters} {incr i} {
      set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_$i"]
    }
    set m_axi_mem [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_HOST"]
    set s_axi_dma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA"]

    # create hierarchical ports: clocks
    set ddr_aclk [create_bd_pin -type "clk" -dir "O" "ddr_aclk"]
    set design_clk [create_bd_pin -type "clk" -dir "O" "design_aclk"]
    set pcie_aclk [tapasco::subsystem::get_port "host" "clk"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]

    # create hierarchical ports: resets
    set ddr_aresetn [create_bd_pin -type "rst" -dir "O" "ddr_aresetn"]
    set design_aresetn [create_bd_pin -type "rst" -dir "O" "design_aresetn"]
    set pcie_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set ddr_ic_aresetn [tapasco::subsystem::get_port "mem" "rst" "interconnect"]
    set ddr_p_aresetn  [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
    set design_p_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    variable pcie_width
    if { $pcie_width == "x8" } {
      set dma [tapasco::ip::create_bluedma "dma"]
    } else {
      set dma [tapasco::ip::create_bluedma_x16 "dma"]
    }
    connect_bd_net [get_bd_pins $dma/IRQ_read] [::tapasco::ip::add_interrupt "PLATFORM_COMPONENT_DMA0_READ" "host"]
    connect_bd_net [get_bd_pins $dma/IRQ_write] [::tapasco::ip::add_interrupt "PLATFORM_COMPONENT_DMA0_WRITE" "host"]

    # instantiate HBM
    set hbm [tapasco::ip::create_hbm "hbm_0"]
    set hbm_properties [list \
      CONFIG.USER_APB_EN {false} \
      CONFIG.USER_SWITCH_ENABLE_00 {true} \
      CONFIG.USER_SWITCH_ENABLE_01 {true} \
      CONFIG.USER_AXI_INPUT_CLK_FREQ [tapasco::get_mem_frequency] \
      CONFIG.USER_XSDB_INTF_EN {TRUE} \
      CONFIG.USER_HBM_DENSITY {8GB} \
      CONFIG.USER_CLK_SEL_LIST1 {AXI_31_ACLK} \
    ]

    # disable HBM ports if we have less than 31 PEs
    for {set i $num_masters} {$i < 31} {incr i} {
      set saxi [format %02s $i]
      lappend hbm_properties CONFIG.USER_SAXI_${saxi} {false}
    }

    for {set i 0} {$i < 32} {incr i} {
      if [expr {($i %2) == 0}] {
        set mc [format %s [expr {$i / 2}]]
        lappend hbm_properties CONFIG.USER_MC${mc}_ECC_BYPASS true
        lappend hbm_properties CONFIG.USER_MC${mc}_EN_DATA_MASK true
        lappend hbm_properties CONFIG.USER_MC${mc}_TRAFFIC_OPTION {Linear}
        lappend hbm_properties CONFIG.USER_MC${mc}_BG_INTERLEAVE_EN true
      }
    }
    set_property -dict $hbm_properties $hbm

    # create clocks and resets
    set hbm_clk_buf [tapasco::ip::create_util_buf hbm_clk_buf]
    apply_board_connection -board_interface "hbm_clk" -ip_intf "${hbm_clk_buf}/CLK_IN_D" -diagram "system"
    connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins ${hbm}/HBM_REF_CLK_0]
    connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins ${hbm}/HBM_REF_CLK_1]

    # generate clocks:
    # 1. Memory clock (300 MHz)
    # 2. Design clock (design frequency)
    # 3. HBM clock (450 MHz)
    set memory_clk_wiz [tapasco::ip::create_clk_wiz memory_clk_wiz]
    set_property -dict [list CONFIG.NUM_OUT_CLKS {3} \
      CONFIG.CLK_OUT1_PORT {memory_clk} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [tapasco::get_mem_frequency] \
      CONFIG.CLKOUT2_USED {true} \
      CONFIG.CLK_OUT2_PORT {design_clk} \
      CONFIG.CLKOUT2_REQUESTED_OUT_FREQ [tapasco::get_design_frequency] \
      CONFIG.CLKOUT3_USED {true} \
      CONFIG.CLK_OUT3_PORT {hbm_clk} \
      CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {450.000} \
      CONFIG.USE_SAFE_CLOCK_STARTUP {false} \
      CONFIG.USE_LOCKED {true} \
      CONFIG.USE_RESET {false} \
      CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    ] $memory_clk_wiz
    connect_bd_net [get_bd_pins $memory_clk_wiz/clk_in1] [get_bd_pins $hbm_clk_buf/IBUF_OUT]

    set apb_rst_gen [tapasco::ip::create_rst_gen "apb_rst_gen"]
    connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins $hbm/APB_0_PCLK]
    connect_bd_net [get_bd_pins $apb_rst_gen/peripheral_aresetn] [get_bd_pins $hbm/APB_0_PRESET_N]
    connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins $hbm/APB_1_PCLK]
    connect_bd_net [get_bd_pins $apb_rst_gen/peripheral_aresetn] [get_bd_pins $hbm/APB_1_PRESET_N]
    connect_bd_net [get_bd_pins ${hbm_clk_buf}/IBUF_OUT] [get_bd_pins $apb_rst_gen/slowest_sync_clk]
    connect_bd_net $pcie_p_aresetn [get_bd_pins $apb_rst_gen/ext_reset_in]

    set mem_rst_gen [tapasco::ip::create_rst_gen "mem_rst_gen"]
    connect_bd_net [get_bd_pins $memory_clk_wiz/memory_clk] [get_bd_pins $mem_rst_gen/slowest_sync_clk]
    connect_bd_net [get_bd_pins $memory_clk_wiz/locked] [get_bd_pins $mem_rst_gen/dcm_locked]
    connect_bd_net $pcie_p_aresetn [get_bd_pins $mem_rst_gen/ext_reset_in]

    set hbm_rst_gen [tapasco::ip::create_rst_gen "hbm_rst_gen"]
    connect_bd_net [get_bd_pins $memory_clk_wiz/hbm_clk] [get_bd_pins $hbm_rst_gen/slowest_sync_clk]
    connect_bd_net [get_bd_pins $memory_clk_wiz/locked] [get_bd_pins $hbm_rst_gen/dcm_locked]
    connect_bd_net $pcie_p_aresetn [get_bd_pins $hbm_rst_gen/ext_reset_in]

    set des_rst_gen [tapasco::ip::create_rst_gen "design_rst_gen"]
    connect_bd_net [get_bd_pins $memory_clk_wiz/design_clk] [get_bd_pins $des_rst_gen/slowest_sync_clk]
    connect_bd_net [get_bd_pins $memory_clk_wiz/locked] [get_bd_pins $des_rst_gen/dcm_locked]
    connect_bd_net $pcie_p_aresetn [get_bd_pins $des_rst_gen/ext_reset_in]

    # create Smartconnect between BlueDMA and HBM
    set mig_ic [tapasco::ip::create_axi_sc "mig_ic" 1 1 2]
    connect_bd_net [get_bd_pins $memory_clk_wiz/memory_clk] [get_bd_pins $mig_ic/aclk]
    connect_bd_net [get_bd_pins $memory_clk_wiz/hbm_clk] [get_bd_pins $mig_ic/aclk1]

    # connect HBM AXI clocks and resets
    for {set i 0} {$i < 31} {incr i} {
      if {$i < $num_masters || $i == 31} {
        set port_no [format %02d $i]
        connect_bd_net $design_aclk [get_bd_pins $hbm/AXI_${port_no}_ACLK]
        connect_bd_net $design_p_aresetn [get_bd_pins $hbm/AXI_${port_no}_ARESET_N]
      }
    }
    connect_bd_net [get_bd_pins $memory_clk_wiz/hbm_clk] [get_bd_pins $hbm/AXI_31_ACLK]
    connect_bd_net [get_bd_pins $hbm_rst_gen/peripheral_aresetn] [get_bd_pins $hbm/AXI_31_ARESET_N]

    # AXI connections
    connect_bd_intf_net [get_bd_intf_pins $dma/M32_AXI] [get_bd_intf_pins $mig_ic/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins $dma/M64_AXI] $m_axi_mem
    connect_bd_intf_net [get_bd_intf_pins $mig_ic/M00_AXI] [get_bd_intf_pins $hbm/SAXI_31]
    connect_bd_intf_net $s_axi_dma [get_bd_intf_pins $dma/S_AXI]

    for {set i 0} {$i < $num_masters} {incr i} {
      set port_no [format %02d $i]
      connect_bd_intf_net [get_bd_intf_pins /memory/S_MEM_$i] [get_bd_intf_pins $hbm/SAXI_${port_no}]
    }

    # connect PCIe clock and reset
    connect_bd_net $pcie_aclk [get_bd_pins $dma/m64_axi_aclk] [get_bd_pins $dma/s_axi_aclk]
    connect_bd_net $pcie_p_aresetn [get_bd_pins $dma/m64_axi_aresetn] [get_bd_pins $dma/s_axi_aresetn]

    # connect DDR clock and reset
    set ddr_clk [get_bd_pins $memory_clk_wiz/memory_clk]
    connect_bd_net [tapasco::subsystem::get_port "mem" "clk"] \
      [get_bd_pins $dma/m32_axi_aclk]
    connect_bd_net $ddr_p_aresetn \
      [get_bd_pins $dma/m32_axi_aresetn]

    # connect external DDR clk/rst output ports
    connect_bd_net $ddr_clk $ddr_aclk
    connect_bd_net $ddr_aresetn [get_bd_pins $mem_rst_gen/peripheral_aresetn]

    # connect external design clk
    connect_bd_net [get_bd_pins $memory_clk_wiz/design_clk] $design_clk
    connect_bd_net [get_bd_pins $des_rst_gen/peripheral_aresetn] $design_aresetn

    # set CATTRIP pin to zero
    set const [tapasco::ip::create_constant constz 1 0]
    make_bd_pins_external $const

    # constraints
    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/AU50/board.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]

    set debug_constr_fn "[get_property DIRECTORY [current_project]]/hbm_debug.xdc"
    set debug_constr_file [open $debug_constr_fn w+]
    puts $debug_constr_file {connect_debug_port dbg_hub/clk [get_nets system_i/memory/hbm_clk_buf/IBUF_OUT*]}
    puts $debug_constr_file {set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]}
    close $debug_constr_file
    read_xdc $debug_constr_fn
    set_property PROCESSING_ORDER NORMAL [get_files $debug_constr_fn]
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
