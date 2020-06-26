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
  set platform_dirname "xupvvh"
  set pcie_width "x16"

  source $::env(TAPASCO_HOME_TCL)/platform/pcie/pcie_base.tcl

  if {[tapasco::is_feature_enabled "HBM"]} {

    proc get_ignored_segments { } {
      set hbmInterfaces [hbm::get_hbm_interfaces]
      set ignored [list]
      set numInterfaces [llength $hbmInterfaces]
      if {[expr $numInterfaces % 2] == 1} {
        set max_mem_index [expr $numInterfaces + 1]
      } else {
        set max_mem_index $numInterfaces
      }
      for {set i 0} {$i < $numInterfaces} {incr i} {
        for {set j 0} {$j < $max_mem_index} {incr j} {
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


    # create MIG core
    set mig [tapasco::ip::create_us_ddr ${name}]
    make_bd_intf_pins_external [get_bd_intf_pins $mig/C0_DDR4]

    # create system reset
    set sys_rst_l [create_bd_port -dir I -type rst sys_rst_l]
    set sys_rst_inverter [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 sys_rst_inverter]
    set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] $sys_rst_inverter
    connect_bd_net $sys_rst_l [get_bd_pins $sys_rst_inverter/Op1]
    connect_bd_net [get_bd_pins $sys_rst_inverter/Res] [get_bd_pins $mig/sys_rst]

    # create system clock
    set sys_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 ddr4_sys_clk_1 ]
    connect_bd_intf_net $sys_clk [get_bd_intf_pins $mig/C0_SYS_CLK]
    set_property CONFIG.FREQ_HZ 100000000 $sys_clk

    # configure MIG core
    set part_file "[get_property DIRECTORY [current_project]]/MTA18ADF2G72PZ-2G3.csv"
    if { [file exists $part_file] == 1} {
      puts "Delete MIG configuration from project directory"
      file delete $part_file
    }
    puts "Copying MIG configuration to project directory"
    file copy "$::env(TAPASCO_HOME_TCL)/platform/xupvvh/MTA18ADF2G72PZ-2G3.csv" $part_file

    set properties  [list CONFIG.C0.DDR4_TimePeriod {833} \
      CONFIG.C0.DDR4_InputClockPeriod {9996} \
      CONFIG.C0.DDR4_CLKOUT0_DIVIDE {5} \
      CONFIG.C0.DDR4_MemoryType {RDIMMs} \
      CONFIG.C0.DDR4_MemoryPart {MTA18ADF2G72PZ-2G3} \
      CONFIG.C0.DDR4_DataWidth {72} \
      CONFIG.C0.DDR4_DataMask {NONE} \
      CONFIG.C0.DDR4_CasWriteLatency {16} \
      CONFIG.C0.DDR4_AxiDataWidth {512} \
      CONFIG.C0.DDR4_AxiAddressWidth {34} \
      CONFIG.C0.DDR4_CustomParts $part_file \
      CONFIG.C0.DDR4_isCustom {true} \
      ]


    set_property -dict $properties $mig


    # connect MEM_CTRL interface (ECC configuration + status)
    set s_axi_mem_ctrl [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_MEM_CTRL]

    set m_axi_mem_ctrl [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 /host/M_MEM_CTRL]

    set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells /host/out_ic]]
    set num_mi [expr "$num_mi_old + 1"]
    set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells /host/out_ic]

    connect_bd_intf_net [get_bd_intf_pins $mig/C0_DDR4_S_AXI_CTRL] $s_axi_mem_ctrl
    connect_bd_intf_net $s_axi_mem_ctrl $m_axi_mem_ctrl
    connect_bd_intf_net $m_axi_mem_ctrl [get_bd_intf_pins /host/out_ic/[format "M%02d_AXI" $num_mi_old]]


    create_ddr4_constraints

    return $mig
  }

  proc create_ddr4_constraints {} {
    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/xupvvh/ddr4.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
  }
  

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."

    # create PCIe Clock
    set pcie_sys_clk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_sys_clk]
    set pcie_sys_clk_ibuf [tapasco::ip::create_util_buf refclk_ibuf]
    set_property -dict [ list CONFIG.C_BUF_TYPE {IBUFDSGTE}  ] $pcie_sys_clk_ibuf

    # create PCIe reset
    set pcie_sys_reset_l [create_bd_port -dir I -type rst pcie_sys_reset_l]
    set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $pcie_sys_reset_l

    # create PCIe core
    set pcie_7x_mgt [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_7x_mgt]
    set pcie_core [tapasco::ip::create_axi_pcie3_0_usp axi_pcie3_0]

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
      CONFIG.SYS_RST_N_BOARD_INTERFACE {Custom} \
      CONFIG.PCIE_BOARD_INTERFACE {Custom} \
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

    set_property -dict $pcie_properties $pcie_core

    # create connections
    connect_bd_intf_net $pcie_7x_mgt [get_bd_intf_pins $pcie_core/pcie_mgt]
    connect_bd_intf_net $pcie_sys_clk [get_bd_intf_pins $pcie_sys_clk_ibuf/CLK_IN_D]
    connect_bd_net [get_bd_pins $pcie_core/sys_clk] [get_bd_pins $pcie_sys_clk_ibuf/IBUF_DS_ODIV2]
    connect_bd_net [get_bd_pins $pcie_core/sys_clk_gt] [get_bd_pins $pcie_sys_clk_ibuf/IBUF_OUT]
    connect_bd_net $pcie_sys_reset_l [get_bd_pins $pcie_core/sys_rst_n]


    tapasco::ip::create_msixusptrans "MSIxTranslator" $pcie_core

    create_constraints

    return $pcie_core
  }

  proc create_constraints {} {
    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/xupvvh/board.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
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
      set regslice [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 $subsystem/regslice_${name}]
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

  namespace eval xupvvh {
        namespace export addressmap

        proc addressmap {args} {
            # add ECC config to platform address map
            set args [lappend args "M_MEM_CTRL" [list 0x40000 0x10000 0 "PLATFORM_COMPONENT_ECC"]]
            return $args
        }
    }


  tapasco::register_plugin "platform::xupvvh::addressmap" "post-address-map"

  tapasco::register_plugin "platform::insert_regslices" "post-platform"

}
