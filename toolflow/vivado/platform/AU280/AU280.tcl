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
  set platform_dirname "AU280"
  set pcie_width "x16"

  if { [::tapasco::vivado_is_newer "2020.1"] == 0 } {
    puts "Vivado [version -short] is too old to support AU280."
    exit 1
  }

  source $::env(TAPASCO_HOME_TCL)/platform/pcie/pcie_base.tcl

  if {[tapasco::is_feature_enabled "HBM"]} {

    proc get_ignored_segments { } {
      set hbmInterfaces [hbm::get_hbm_interfaces]
      set ignored [list]
      for {set i 0} {$i < [llength $hbmInterfaces]} {incr i} {
        for {set j 0} {$j < [llength $hbmInterfaces]} {incr j} {
          set axi_index [format %02s $i]
          set mem_index [format %02s $j]
          lappend ignored "/hbm/hbm_0/SAXI_${axi_index}/HBM_MEM${mem_index}"
        }
      }
      return $ignored
    }

  }

  proc create_mig_core {name} {
    puts "Creating MIG core for DDR ..."
    set s_axi_host [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_CTRL"]

    set mig [tapasco::ip::create_us_ddr ${name}]
    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {ddr4_sdram_c1 ( DDR4 SDRAM C1 ) } Manual_Source {Auto}}  [get_bd_intf_pins $mig/C0_DDR4]
    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {sysclk1 ( 100 MHz System differential clock1 ) } Manual_Source {Auto}}  [get_bd_intf_pins $mig/C0_SYS_CLK]
    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {resetn ( FPGA Resetn ) } Manual_Source {New External Port (ACTIVE_HIGH)}}  [get_bd_pins $mig/sys_rst]


    connect_bd_intf_net [get_bd_intf_pins $mig/C0_DDR4_S_AXI_CTRL] $s_axi_host

    set const [tapasco::ip::create_constant constz 1 0]
    make_bd_pins_external $const

    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/AU280/board.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]

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

    set pcie_core [tapasco::ip::create_axi_pcie3_0_usp axi_pcie3_0]

    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {pci_express_x16 ( PCI Express ) } Manual_Source {Auto}}  [get_bd_intf_pins $pcie_core/pcie_mgt]
    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {pcie_perstn ( PCI Express ) } Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins $pcie_core/sys_rst_n]

    apply_bd_automation -rule xilinx.com:bd_rule:xdma -config { accel {1} auto_level {IP Level} axi_clk {Maximum Data Width} axi_intf {AXI Memory Mapped} bar_size {Disable} bypass_size {Disable} c2h {4} cache_size {32k} h2c {4} lane_width {X16} link_speed {8.0 GT/s (PCIe Gen 3)}}  [get_bd_cells $pcie_core]

    set pcie_properties [list \
      CONFIG.functional_mode {AXI_Bridge} \
      CONFIG.mode_selection {Advanced} \
      CONFIG.pcie_blk_locn {PCIE4C_X1Y0} \
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

  # Checks if the optional register slice given by the name is enabled (based on regslice feature and default value)
  proc is_regslice_enabled {name default} {
    if {[tapasco::is_feature_enabled "Regslice"]} {
      set regslices [tapasco::get_feature "Regslice"]
      if  {[dict exists $regslices $name]} {
          return [dict get $regslices $name]
        } else {
          return $default
        }
    } else {
      return $default
    }
  }

  # Inserts a new register slice between given master and slave (for SLR crossing)
  proc insert_regslice {name default master slave clock reset subsystem} {
    if {[is_regslice_enabled $name $default]} {
      set regslice [tapasco::ip::create_axi_reg_slice $subsystem/regslice_${name}]
      set_property -dict [list CONFIG.REG_AW {15} CONFIG.REG_AR {15} CONFIG.REG_W {15} CONFIG.REG_R {15} CONFIG.REG_B {15} CONFIG.USE_AUTOPIPELINING {1}] $regslice
      delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins $master]]
      connect_bd_intf_net [get_bd_intf_pins $master] [get_bd_intf_pins $regslice/S_AXI]
      connect_bd_intf_net [get_bd_intf_pins $regslice/M_AXI] [get_bd_intf_pins $slave]
      connect_bd_net [get_bd_pins $clock] [get_bd_pins $regslice/aclk]
      connect_bd_net [get_bd_pins $reset] [get_bd_pins $regslice/aresetn]
    }
  }

  # Insert optional register slices
  proc insert_regslices {} {
    insert_regslice "dma_migic" false "/memory/dma/m32_axi" "/memory/mig_ic/S00_AXI" "/memory/mem_clk" "/memory/mem_peripheral_aresetn" "/memory"
    insert_regslice "host_memctrl" true "/host/M_MEM_CTRL" "/memory/S_MEM_CTRL" "/clocks_and_resets/mem_clk" "/clocks_and_resets/mem_interconnect_aresetn" ""
    insert_regslice "arch_mem" false "/arch/M_MEM_0" "/memory/S_MEM_0" "/clocks_and_resets/design_clk" "/clocks_and_resets/design_interconnect_aresetn" ""
    insert_regslice "host_dma" true "/host/M_DMA" "/memory/S_DMA" "/clocks_and_resets/host_clk" "/clocks_and_resets/host_interconnect_aresetn" ""
    insert_regslice "dma_host" true "/memory/M_HOST" "/host/S_HOST" "/clocks_and_resets/host_clk" "/clocks_and_resets/host_interconnect_aresetn" ""
    insert_regslice "host_arch" true "/host/M_ARCH" "/arch/S_ARCH" "/clocks_and_resets/design_clk" "/clocks_and_resets/design_interconnect_aresetn" ""
    insert_regslice "l2_cache" [tapasco::is_feature_enabled "Cache"] "/memory/cache_l2_0/M0_AXI" "/memory/mig/C0_DDR4_S_AXI" "/clocks_and_resets/mem_clk" "/clocks_and_resets/mem_peripheral_aresetn" "/memory"

    insert_regslice "host_mmu" [tapasco::is_feature_enabled "SVM"] "/host/M_MMU" "/memory/S_MMU" "/clocks_and_resets/host_clk" "/clocks_and_resets/host_interconnect_aresetn" ""

    if {[is_regslice_enabled "pe" false]} {
      set ips [get_bd_cells /arch/target_ip_*]
      foreach ip $ips {
        set masters [tapasco::get_aximm_interfaces $ip]
        foreach master $masters {
          set slave [get_bd_intf_pins -filter {MODE == Slave} -of_objects [get_bd_intf_nets -of_objects $master]]
          insert_regslice [get_property NAME $ip] true $master $slave "/arch/design_clk" "/arch/design_interconnect_aresetn" "/arch"
        }
      }
    }
  }

  namespace eval AU280 {
        namespace export addressmap

        proc addressmap {args} {
            # add ECC config to platform address map
            set args [lappend args "M_MEM_CTRL" [list 0x50000 0x10000 0 "PLATFORM_COMPONENT_ECC"]]
            return $args
        }
    }


  tapasco::register_plugin "platform::AU280::addressmap" "post-address-map"

  tapasco::register_plugin "platform::insert_regslices" "post-platform"

}
