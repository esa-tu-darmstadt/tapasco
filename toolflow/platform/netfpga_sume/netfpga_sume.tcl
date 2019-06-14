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
# @file		netfpga_sume.tcl
# @brief	Netfpga SUME platform implementation.
# @author	J. A. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
#
namespace eval platform {
  set platform_dirname "netfpga_sume"

  source $::env(TAPASCO_HOME)/platform/pcie/pcie_base.tcl

  proc create_mig_core {name} {
    puts "Creating MIG core for DDR ..."
    set copy_to "[get_property DIRECTORY [current_project]]/nf_sume_ddr3A.prj"
    if { [file exists $copy_to] == 1} {
      puts "Delete MIG configuration to project directory"
      file delete $copy_to
    }
    puts "Copying MIG configuration to project directory"
    file copy "$::env(TAPASCO_HOME)/platform/netfpga_sume/nf_sume_ddr3A.prj" $copy_to
    # create the IP core itself
    set mig_7series_0 [tapasco::ip::create_mig_core $name]
    puts "Initializing MIG settings"
    # set MIG properties
    set_property -dict [ list \
    CONFIG.XML_INPUT_FILE $copy_to \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
    CONFIG.BOARD_MIG_PARAM {Custom}] $mig_7series_0

    set sys_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk ]
    connect_bd_intf_net $sys_clk [get_bd_intf_pins $name/SYS_CLK]
    set_property CONFIG.FREQ_HZ 233333333 $sys_clk

    set clk_ref_i [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 clk_ref ]
    connect_bd_intf_net $clk_ref_i [get_bd_intf_pins $name/CLK_REF]
    set_property CONFIG.FREQ_HZ 200000000 $clk_ref_i

    make_bd_pins_external  [get_bd_pins $name/sys_rst]

    make_bd_intf_pins_external [get_bd_intf_pins $mig_7series_0/DDR3]

    return $mig_7series_0
  }

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."
    # create ports
    set pcie_7x_mgt [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_7x_mgt ]
    set IBUF_DS_N [ create_bd_port -dir I -from 0 -to 0 IBUF_DS_N ]
    set IBUF_DS_P [ create_bd_port -dir I -from 0 -to 0 IBUF_DS_P ]
    set pcie_perst [ create_bd_port -dir I -type rst pcie_perst ]
    set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $pcie_perst
    # create PCIe core
    set axi_pcie3_0 [tapasco::ip::create_axi_pcie3_0 "axi_pcie3_0"]
    set pcie_properties [list \
      CONFIG.axi_data_width {256_bit} \
      CONFIG.pcie_blk_locn {X0Y1} \
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
    # create refclk_ibuf
    set refclk_ibuf [tapasco::ip::create_util_buf refclk_ibuf]
    set_property -dict [ list CONFIG.C_BUF_TYPE {IBUFDSGTE}  ] $refclk_ibuf
    # connect wires
    connect_bd_intf_net $pcie_7x_mgt [get_bd_intf_pins axi_pcie3_0/pcie_7x_mgt]
    connect_bd_net $IBUF_DS_N [get_bd_pins refclk_ibuf/IBUF_DS_N]
    connect_bd_net $IBUF_DS_P [get_bd_pins refclk_ibuf/IBUF_DS_P]
    connect_bd_net $pcie_perst [get_bd_pins axi_pcie3_0/sys_rst_n]
    connect_bd_net [get_bd_pins axi_pcie3_0/refclk] [get_bd_pins refclk_ibuf/IBUF_OUT]

    create_constraints

    return $axi_pcie3_0
  }

  proc create_constraints {} {
    set constraints_fn "$::env(TAPASCO_HOME)/platform/netfpga_sume/board.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
  }

}
