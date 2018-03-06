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
    puts "MIG core not integrated for Netfpga SUME"
    puts "Adding BRAM for local memory"

    set instance [current_bd_instance .]
    set cell [create_bd_cell -type hier ${instance}/$name]
    current_bd_instance $cell

    set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI"]
    set ui_clk [create_bd_pin -type "clk" -dir "O" "ui_clk"]
    set ui_clk [create_bd_pin -type "reset" -dir "O" "ui_clk_sync_rst"]

    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.0 mig
    set_property -dict [list CONFIG.DATA_WIDTH {512} CONFIG.SINGLE_PORT_BRAM {1} CONFIG.ECC_TYPE {0}] [get_bd_cells mig]
    apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins mig/BRAM_PORTA]

    tapasco::ip::create_clk_wiz clk_wiz_0
    set_property -dict [list CONFIG.CLK_OUT1_PORT {ui_clk} \
                        CONFIG.USE_SAFE_CLOCK_STARTUP {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [tapasco::get_mem_frequency] \
                        CONFIG.USE_LOCKED {false} \
                        CONFIG.USE_RESET {false}] [get_bd_cells clk_wiz_0]

    connect_bd_intf_net [get_bd_intf_pins mig/S_AXI] $s_axi
    connect_bd_net [get_bd_pins clk_wiz_0/ui_clk] $ui_clk

    # exit the hierarchical group
    current_bd_instance $instance

    connect_bd_net [get_bd_pins host_clk] [get_bd_pins ${name}/clk_wiz_0/clk_in1]
    connect_bd_net [get_bd_pins mem_clk] [get_bd_pins ${name}/mig/s_axi_aclk]
    connect_bd_net [get_bd_pins mem_peripheral_aresetn] [get_bd_pins ${name}/mig/s_axi_aresetn]
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
    set refclk_ibuf [create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 refclk_ibuf ]
    set_property -dict [ list CONFIG.C_BUF_TYPE {IBUFDSGTE}  ] $refclk_ibuf
    # connect wires
    connect_bd_intf_net $pcie_7x_mgt [get_bd_intf_pins axi_pcie3_0/pcie_7x_mgt]
    connect_bd_net $IBUF_DS_N [get_bd_pins refclk_ibuf/IBUF_DS_N]
    connect_bd_net $IBUF_DS_P [get_bd_pins refclk_ibuf/IBUF_DS_P]
    connect_bd_net $pcie_perst [get_bd_pins axi_pcie3_0/sys_rst_n]
    connect_bd_net [get_bd_pins axi_pcie3_0/refclk] [get_bd_pins refclk_ibuf/IBUF_OUT]
    # create constraints file for GTX transceivers
    set constraints_fn "[get_property DIRECTORY [current_project]]/pcie.xdc"
    set constraints_file [open $constraints_fn w+]
    puts $constraints_file "set_property LOC IBUFDS_GTE2_X1Y11 \[get_cells {system_i/PCIe/refclk_ibuf/U0/USE_IBUFDS_GTE2.GEN_IBUFDS_GTE2[0].IBUFDS_GTE2_I}\]"
    close $constraints_file
    read_xdc $constraints_fn

    create_constraints

    return $axi_pcie3_0
  }

  proc create_constraints {} {

    set constraints_fn "[get_property DIRECTORY [current_project]]/board.xdc"
    set constraints_file [open $constraints_fn w+]

    puts $constraints_file "#The following two properties should be set for every design"
    puts $constraints_file "set_property CFGBVS GND \[current_design\]"
    puts $constraints_file "set_property CONFIG_VOLTAGE 1.8 \[current_design\]"
    puts $constraints_file "#System Clock signal (200 MHz)"
    puts $constraints_file "set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVDS     } \[get_ports { sys_clk_clk_n }\]; #IO_L13N_T2_MRCC_38 Sch=fpga_sysclk_n"
    puts $constraints_file "set_property -dict { PACKAGE_PIN H19   IOSTANDARD LVDS     } \[get_ports { sys_clk_clk_p }\]; #IO_L13P_T2_MRCC_38 Sch=fpga_sysclk_p"
    puts $constraints_file "set_property IOSTANDARD DIFF_SSTL15 \[get_ports { sys_clk_clk_* }\]"
    puts $constraints_file "create_clock -add -name sys_clk_pin -period 5.00 -waveform {0 2.5} \[get_ports {sys_clk_clk_p}\];"
    #puts $constraints_file "#DDR_SYS_CLK (233.3333MHz)"
    #puts $constraints_file "# Note: This clock is used by the MIG for the DDR3 SODIMM. It should not be used for other purposes in designs that use the DDR3"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN E35   IOSTANDARD LVDS     } \[get_ports { DDR3_SYSCLK_N }\]; #IO_L13N_T2_MRCC_35 Sch=ddr3_sysclk_n"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN E34   IOSTANDARD LVDS     } \[get_ports { DDR3_SYSCLK_P }\]; #IO_L13P_T2_MRCC_35 Sch=ddr3_sysclk_p"
    #puts $constraints_file "create_clock -add -name ddr_clk_pin -period 4.285715 -waveform {0 2.1428575} \[get_ports {DDR3_SYSCLK_P}\];"
    puts $constraints_file "#PCIe Transceiver clock (100 MHz)"
    puts $constraints_file "# Note: This clock is attached to a MGTREFCLK pin"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AB7 } \[get_ports { IBUF_DS_N }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AB8 } \[get_ports { IBUF_DS_P }\];"

    puts $constraints_file "set_property LOC AY35 \[get_ports { pcie_perst }\]"
    puts $constraints_file "set_property IOSTANDARD LVCMOS18    \[get_ports { pcie_perst }\]"
    puts $constraints_file "set_property PULLUP true \[get_ports { pcie_perst }\]"
    puts $constraints_file "set_false_path -from \[get_ports pcie_perst\]"

    puts $constraints_file "create_clock -add -name pcie_clk_pin -period 10.000 -waveform {0 5.000} \[get_ports {IBUF_DS_P}\];"
    #puts $constraints_file "#PCIe Transceivers"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN Y4 } \[get_ports { pcie_7x_mgt_txp[0] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN Y3 } \[get_ports { pcie_7x_mgt_txn[0] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN W2 } \[get_ports { pcie_7x_mgt_rxp[0] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN W1 } \[get_ports { pcie_7x_mgt_rxn[0] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AA6 } \[get_ports { pcie_7x_mgt_txp[1] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AA5 } \[get_ports { pcie_7x_mgt_txn[1] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AA2 } \[get_ports { pcie_7x_mgt_rxp[1] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AA1 } \[get_ports { pcie_7x_mgt_rxn[1] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AB4 } \[get_ports { pcie_7x_mgt_txp[2] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AB3 } \[get_ports { pcie_7x_mgt_txn[2] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AC2 } \[get_ports { pcie_7x_mgt_rxp[2] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AC1 } \[get_ports { pcie_7x_mgt_rxn[2] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AC6 } \[get_ports { pcie_7x_mgt_txp[3] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AC5 } \[get_ports { pcie_7x_mgt_txn[3] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AE2 } \[get_ports { pcie_7x_mgt_rxp[3] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AE1 } \[get_ports { pcie_7x_mgt_rxn[3] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AD4 } \[get_ports { pcie_7x_mgt_txp[4] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AD3 } \[get_ports { pcie_7x_mgt_txn[4] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AG2 } \[get_ports { pcie_7x_mgt_rxp[4] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AG1 } \[get_ports { pcie_7x_mgt_rxn[4] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AE6 } \[get_ports { pcie_7x_mgt_txp[5] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AE5 } \[get_ports { pcie_7x_mgt_txn[5] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AH4 } \[get_ports { pcie_7x_mgt_rxp[5] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AH3 } \[get_ports { pcie_7x_mgt_rxn[5] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AF4 } \[get_ports { pcie_7x_mgt_txp[6] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AF3 } \[get_ports { pcie_7x_mgt_txn[6] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AJ2 } \[get_ports { pcie_7x_mgt_rxp[6] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AJ1 } \[get_ports { pcie_7x_mgt_rxn[6] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AG6 } \[get_ports { pcie_7x_mgt_txp[7] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AG5 } \[get_ports { pcie_7x_mgt_txn[7] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AK4 } \[get_ports { pcie_7x_mgt_rxp[7] }\];"
    #puts $constraints_file "set_property -dict { PACKAGE_PIN AK3 } \[get_ports { pcie_7x_mgt_rxn[7] }\];"

    close $constraints_file
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
  }

}
