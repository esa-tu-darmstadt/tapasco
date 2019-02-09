#
# Copyright (C) 2017 Jens Korinth, TU Darmstadt
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
# @file		aws.tcl
# @brief	AWS F1 platform implementation.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
# @author	J. A. Hofmann, TU Darmstadt (jah@esa.tu-darmstadt.de)
#
namespace eval platform {

  set platform_dirname "aws"

  source $::env(TAPASCO_HOME)/platform/pcie/pcie_base.tcl

  proc create_mig_core {name} {
    puts "Creating MIG core for DDR ..."
    # create ports
    set ddr3_sdram_socket_j1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr3_sdram_socket_j1 ]
    set sys_diff_clock [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_diff_clock ]
    set_property -dict [ list CONFIG.FREQ_HZ {100000000}  ] $sys_diff_clock
    set reset [ create_bd_port -dir I -type rst reset ]
    set_property -dict [ list CONFIG.POLARITY {ACTIVE_HIGH}  ] $reset
    # create the IP core itself
    set mig_7series_0 [tapasco::ip::create_mig_core $name]
    # generate the PRJ File for MIG
    set str_mig_folder [get_property IP_DIR [ get_ips [ get_property CONFIG.Component_Name $mig_7series_0 ] ] ]
    set str_mig_file_name mig_a.prj
    set str_mig_file_path ${str_mig_folder}/${str_mig_file_name}
    write_mig_file_design_1_mig_7series_0_0 $str_mig_file_path
    # set MIG properties
    set_property -dict [ list CONFIG.BOARD_MIG_PARAM {ddr3_sdram_socket_j1} CONFIG.MIG_DONT_TOUCH_PARAM {Custom} CONFIG.RESET_BOARD_INTERFACE {reset} CONFIG.XML_INPUT_FILE {mig_a.prj}  ] $mig_7series_0
    # connect wires
    connect_bd_intf_net $ddr3_sdram_socket_j1 [get_bd_intf_pins $name/DDR3]
    connect_bd_intf_net $sys_diff_clock [get_bd_intf_pins $name/SYS_CLK]
    connect_bd_net $reset [get_bd_pins $name/sys_rst]
    return $mig_7series_0
  }

  proc create_pcie_core {} {

    puts "Creating AWS F1 Shell ..."

    # #if { $parentCell eq "" } {
    #  set parentCell [get_bd_cells /]
    # #}

    # # Get object for parentCell
    # set parentObj [get_bd_cells $parentCell]
    # if { $parentObj == "" } {
    #  catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
    #  return
    # }

    # # Make sure parentObj is hier blk
    # set parentType [get_property TYPE $parentObj]
    # if { $parentType ne "hier" } {
    #  catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
    #  return
    # }

    # # Save current instance; Restore later
    # set oldCurInst [current_bd_instance .]

    # # Set parent object as current
    # current_bd_instance $parentObj

#           set_property  ip_repo_paths  [file join $_nsvars::script_dir ip]  [current_project]
    set_property ip_repo_paths [file join $::env(AWS_FPGA_REPO_DIR)/hdk/common/shell_v04261818/hlx/design/ip/aws_v1_0] [current_project]
#TODO: FILE CR, adding PWD
#           set_property  ip_repo_paths  [list [get_property ip_repo_paths [current_project]] [file join $_nsvars::script_dir ip] ] [current_project]
    update_ip_catalog


      # Create interface ports
    set S_SH [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aws_f1_sh1_rtl:1.0 S_SH ]

    # Create instance: f1_inst, and set properties
    set f1_inst [ create_bd_cell -type ip -vlnv xilinx.com:ip:aws:1.0 f1_inst ]
    set_property -dict [ list \
        CONFIG.AUX_PRESENT {1} \
        CONFIG.BAR1_PRESENT {1} \
        CONFIG.CLOCK_A0_FREQ {125000000} \
        CONFIG.CLOCK_A1_FREQ {62500000} \
        CONFIG.CLOCK_A2_FREQ {187500000} \
        CONFIG.CLOCK_A3_FREQ {250000000} \
        CONFIG.CLOCK_A_RECIPE {0} \
        CONFIG.DEVICE_ID {0xF000} \
        CONFIG.PCIS_PRESENT {1} \
    ] $f1_inst

    # Connect S_SH pin
    set oldCurInst [current_bd_instance .]
    current_bd_instance
    connect_bd_intf_net $S_SH [get_bd_intf_pins $f1_inst/S_SH]    
    current_bd_instance $oldCurInst    

    save_bd_design

    return $f1_inst

    # puts "Creating AXI PCIe Gen3 bridge ..."
    # # create ports
    # set pcie_7x_mgt [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_7x_mgt ]
    # set IBUF_DS_N [ create_bd_port -dir I -from 0 -to 0 IBUF_DS_N ]
    # set IBUF_DS_P [ create_bd_port -dir I -from 0 -to 0 IBUF_DS_P ]
    # set pcie_perst [ create_bd_port -dir I -type rst pcie_perst ]
    # set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $pcie_perst
    # # create PCIe core
    # set axi_pcie3_0 [tapasco::ip::create_axi_pcie3_0 "axi_pcie3_0"]
    # set pcie_properties [list \
    #   CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perst} \
    #   CONFIG.axi_data_width {256_bit} \
    #   CONFIG.pcie_blk_locn {X0Y1} \
    #   CONFIG.pf0_bar0_64bit {true} \
    #   CONFIG.pf0_bar0_scale {Megabytes} \
    #   CONFIG.pf0_bar0_size {64} \
    #   CONFIG.pf0_device_id {7038} \
    #   CONFIG.pl_link_cap_max_link_width {X8} \
    #   CONFIG.pipe_sim {true} \
    #   CONFIG.comp_timeout {50ms} \
    #   CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
    #   CONFIG.axisten_freq {250} \
    #   CONFIG.axi_addr_width {64} \
    #   CONFIG.pf0_msi_enabled {false} \
    #   CONFIG.pf0_msix_enabled {true} \
    #   CONFIG.pf0_msix_cap_table_size {83} \
    #   CONFIG.pf0_msix_cap_table_offset {500000} \
    #   CONFIG.pf0_msix_cap_pba_offset {508000} \
    #   CONFIG.comp_timeout {50ms} \
    #   CONFIG.pf0_interrupt_pin {NONE} \
    #   CONFIG.c_s_axi_supports_narrow_burst {false} \
    # ]

    # # enable ATS/PRI (if platform feature is set)
    # if {[tapasco::is_feature_enabled "ATS-PRI"]} {
    #   puts "  ATS/PRI support is enabled"
    #   lappend pcie_properties \
    #     CONFIG.c_ats_enable {true} \
    #     CONFIG.c_pri_enable {true} \
    # }
    # set_property -dict $pcie_properties $axi_pcie3_0
    # # create refclk_ibuf
    # set refclk_ibuf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 refclk_ibuf ]
    # set_property -dict [ list CONFIG.C_BUF_TYPE {IBUFDSGTE}  ] $refclk_ibuf
    # # connect wires
    # connect_bd_intf_net $pcie_7x_mgt [get_bd_intf_pins axi_pcie3_0/pcie_7x_mgt]
    # connect_bd_net $IBUF_DS_N [get_bd_pins refclk_ibuf/IBUF_DS_N]
    # connect_bd_net $IBUF_DS_P [get_bd_pins refclk_ibuf/IBUF_DS_P]
    # connect_bd_net $pcie_perst [get_bd_pins axi_pcie3_0/sys_rst_n]
    # connect_bd_net [get_bd_pins axi_pcie3_0/refclk] [get_bd_pins refclk_ibuf/IBUF_OUT]
    # # create constraints file for GTX transceivers
    # set constraints_fn "[get_property DIRECTORY [current_project]]/pcie.xdc"
    # set constraints_file [open $constraints_fn w+]
    # puts $constraints_file "set_property LOC IBUFDS_GTE2_X1Y11 \[get_cells {system_i/host/refclk_ibuf/U0/USE_IBUFDS_GTE2.GEN_IBUFDS_GTE2[0].IBUFDS_GTE2_I}\]"
    # close $constraints_file
    # read_xdc $constraints_fn

    # return $axi_pcie3_0
  }

}
