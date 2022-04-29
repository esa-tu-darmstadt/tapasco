# Copyright (c) 2014-2022 Embedded Systems and Applications, TU Darmstadt.
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

  if {[version -short] != "2021.2"} {
    puts "Only Vivado 2021.2 is currently supported for Versal devices."
    exit 1
  }

  if { ! [info exists pcie_width] } {
    puts "No PCIe width defined. Assuming x8..."
    set pcie_width "8"
  } else {
    puts "Using PCIe width $pcie_width."
  }

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/versal/plugins" "*.tcl"] {
    source -notrace $f
  }

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/${platform_dirname}/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list [::tapasco::get_platform_num_slots]]
  }

  proc number_of_interrupt_controllers {} {
    return 1
  }

  proc get_platform_base_address {} {
    return 0
  }

  proc create_subsystem_clocks_and_resets {} {
    # PCIe clock as input
    set pcie_clk [create_bd_pin -type "clk" -dir "I" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "I" "pcie_aresetn"]

    # Clocking wizard for design clock
    set design_clk_wiz [tapasco::ip::create_clk_wizard design_clk_wiz]

    set_property -dict [list CONFIG.USE_SAFE_CLOCK_STARTUP {false} \
                        CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY [tapasco::get_design_frequency] \
                        CONFIG.USE_LOCKED {true} \
                        CONFIG.USE_RESET {true} \
                        CONFIG.RESET_TYPE {ACTIVE_LOW} \
                        CONFIG.RESET_PORT {resetn} \
                        CONFIG.PRIM_SOURCE {No_buffer} \
                        ] $design_clk_wiz

    connect_bd_net [get_bd_pins $design_clk_wiz/resetn] $pcie_aresetn
    connect_bd_net [get_bd_pins $pcie_clk] [get_bd_pins $design_clk_wiz/clk_in1]

    # create reset generator
    set host_rst_gen [tapasco::ip::create_rst_gen "host_rst_gen"]
    set design_rst_gen [tapasco::ip::create_rst_gen "design_rst_gen"]
    set mem_rst_gen [tapasco::ip::create_rst_gen "mem_rst_gen"]

    # connect external ports
    connect_bd_net $pcie_clk [get_bd_pins $host_rst_gen/slowest_sync_clk] [tapasco::subsystem::get_port "host" "clk"]
    connect_bd_net $pcie_aresetn [get_bd_pins $host_rst_gen/ext_reset_in]

    # TODO memory clock is PCIe for now
    connect_bd_net $pcie_clk [get_bd_pins $mem_rst_gen/slowest_sync_clk] [tapasco::subsystem::get_port "mem" "clk"]
    connect_bd_net $pcie_aresetn [get_bd_pins $mem_rst_gen/ext_reset_in]

    connect_bd_net [get_bd_pins $design_clk_wiz/clk_out1] [get_bd_pins $design_rst_gen/slowest_sync_clk] [tapasco::subsystem::get_port "design" "clk"]
    connect_bd_net [get_bd_pins $design_clk_wiz/locked] [get_bd_pins $design_rst_gen/ext_reset_in]

    # connect to clock reset master
    connect_bd_net [get_bd_pins $host_rst_gen/peripheral_aresetn] [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    connect_bd_net [get_bd_pins $host_rst_gen/peripheral_reset] [tapasco::subsystem::get_port "host" "rst" "peripheral" "reset"]
    connect_bd_net [get_bd_pins $host_rst_gen/interconnect_aresetn] [tapasco::subsystem::get_port "host" "rst" "interconnect"]

    connect_bd_net [get_bd_pins $design_rst_gen/peripheral_aresetn] [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    connect_bd_net [get_bd_pins $design_rst_gen/peripheral_reset] [tapasco::subsystem::get_port "design" "rst" "peripheral" "reset"]
    connect_bd_net [get_bd_pins $design_rst_gen/interconnect_aresetn] [tapasco::subsystem::get_port "design" "rst" "interconnect"]

    connect_bd_net [get_bd_pins $mem_rst_gen/peripheral_aresetn] [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
    connect_bd_net [get_bd_pins $mem_rst_gen/peripheral_reset] [tapasco::subsystem::get_port "mem" "rst" "peripheral" "reset"]
    connect_bd_net [get_bd_pins $mem_rst_gen/interconnect_aresetn] [tapasco::subsystem::get_port "mem" "rst" "interconnect"]
  }

  proc create_subsystem_host {} {
    # host subsystem is everything PCIe and QDMA related
    set m_arch [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_ARCH"]
    set m_intc [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_INTC"]
    set m_tapasco [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_TAPASCO"]
    set m_dma [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DMA"]
    set m_desc_gen [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DESC_GEN"]
    set s_desc_gen [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DESC_GEN"]

    set pcie_aclk [create_bd_pin -type "clk" -dir "O" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "O" "pcie_aresetn"]

    set qdma [tapasco::ip::create_qdma qdma_0]
    variable pcie_width
    # first set pcie location to a value which supports x8/x16, otherwise block automation will fail
    set_property CONFIG.pcie_blk_locn {X0Y2} $qdma
    apply_bd_automation -rule xilinx.com:bd_rule:qdma -config [list axi_strategy {max_data} link_speed {3} link_width $pcie_width pl_pcie_cpm {PL-PCIE}] $qdma

    set_property -dict [list CONFIG.mode_selection {Advanced} \
      CONFIG.pcie_blk_locn {X0Y2} \
      CONFIG.pl_link_cap_max_link_width "X$pcie_width" \
      CONFIG.axilite_master_en {false} \
      CONFIG.axist_bypass_en {true} \
      CONFIG.dsc_byp_mode {Descriptor_bypass_and_internal} \
      CONFIG.adv_int_usr {true} \
      CONFIG.pf0_pciebar2axibar_0 [get_platform_base_address] \
      CONFIG.testname {mm} CONFIG.pf0_bar0_type_qdma {AXI_Bridge_Master} \
      CONFIG.pf0_bar0_scale_qdma {Megabytes} \
      CONFIG.pf0_bar0_size_qdma {64} \
      CONFIG.pf0_bar2_type_qdma {DMA} \
      CONFIG.pf0_bar2_size_qdma {256} \
      CONFIG.pf1_bar0_type_qdma {AXI_Bridge_Master} \
      CONFIG.pf1_bar0_scale_qdma {Megabytes} \
      CONFIG.pf1_bar0_size_qdma {64} \
      CONFIG.pf1_bar2_type_qdma {DMA} \
      CONFIG.pf1_bar2_size_qdma {256} \
      CONFIG.pf2_bar0_type_qdma {AXI_Bridge_Master} \
      CONFIG.pf2_bar0_scale_qdma {Megabytes} \
      CONFIG.pf2_bar0_size_qdma {64} \
      CONFIG.pf2_bar2_type_qdma {DMA} \
      CONFIG.pf2_bar2_size_qdma {256} \
      CONFIG.pf3_bar0_type_qdma {AXI_Bridge_Master} \
      CONFIG.pf3_bar0_scale_qdma {Megabytes} \
      CONFIG.pf3_bar0_size_qdma {64} \
      CONFIG.pf3_bar2_type_qdma {DMA} \
      CONFIG.pf3_bar2_size_qdma {256} \
      CONFIG.pf0_device_id {7038} \
      CONFIG.PF0_MSIX_CAP_TABLE_SIZE_qdma {01F} \
      CONFIG.PF0_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
      CONFIG.PF1_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
      CONFIG.PF2_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
      CONFIG.PF3_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
      CONFIG.PF0_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
      CONFIG.PF1_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
      CONFIG.PF2_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
      CONFIG.PF3_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
      CONFIG.dma_intf_sel_qdma {AXI_MM} \
      CONFIG.en_axi_st_qdma {false}] $qdma

    set_property -dict [list CONFIG.PF0_DEVICE_ID {7038} \
      CONFIG.PF0_MSIX_CAP_PBA_BIR {BAR_3:2} \
      CONFIG.PF0_MSIX_CAP_TABLE_BIR {BAR_3:2} \
      CONFIG.PF0_MSIX_CAP_TABLE_SIZE {0FF} \
      CONFIG.PF1_DEVICE_ID {9011} \
      CONFIG.pcie_blk_locn {X0Y2} \
      CONFIG.pf1_bar2_size {256} \
      CONFIG.pf2_bar2_size {256} \
      CONFIG.pf3_bar2_size {256} \
      CONFIG.pf4_bar2_size {256} \
      CONFIG.pf5_bar2_size {256} \
      CONFIG.pf6_bar2_size {256} \
      CONFIG.pf7_bar2_size {256} \
      CONFIG.pf0_bar0_scale {Megabytes} \
      CONFIG.pf0_bar0_size {64} \
      CONFIG.pf0_bar2_size {256} \
      CONFIG.pf1_bar0_scale {Megabytes} \
      CONFIG.pf1_bar0_size {64} \
      CONFIG.pf2_bar0_scale {Megabytes} \
      CONFIG.pf2_bar0_size {64} \
      CONFIG.pf3_bar0_scale {Megabytes} \
      CONFIG.pf3_bar0_size {64} \
      CONFIG.pf4_bar0_scale {Megabytes} \
      CONFIG.pf4_bar0_size {64} \
      CONFIG.pf5_bar0_scale {Megabytes} \
      CONFIG.pf5_bar0_size {64} \
      CONFIG.pf6_bar0_scale {Megabytes} \
      CONFIG.pf6_bar0_size {64} \
      CONFIG.pf7_bar0_scale {Megabytes} \
      CONFIG.pf7_bar0_size {64}] [get_bd_cells /host/qdma_0_support/pcie]

    # TODO: Make configuration device dependent

    set qdma_desc [tapasco::ip::create_qdma_desc_gen "QDMADescriptorGenera_0"]
    connect_bd_intf_net $s_desc_gen $qdma_desc/S_AXI_CTRL
    connect_bd_intf_net $qdma_desc/c2h_byp_in $qdma/c2h_byp_in_mm
    connect_bd_intf_net $qdma_desc/h2c_byp_in $qdma/h2c_byp_in_mm
    connect_bd_intf_net $qdma_desc/tm_dsc_sts $qdma/tm_dsc_sts
    connect_bd_intf_net $qdma_desc/qsts_out $qdma/qsts_out
    connect_bd_intf_net $qdma_desc/c2h_byp_out $qdma/c2h_byp_out
    connect_bd_intf_net $qdma_desc/h2c_byp_out $qdma/h2c_byp_out

    set qdma_conf [tapasco::ip::create_qdma_configurator "QDMAConfigurator_0"]
    connect_bd_intf_net [get_bd_intf_pins $qdma_conf/msix_vector_ctrl] [get_bd_intf_pins $qdma/msix_vector_ctrl]

    connect_bd_intf_net $qdma/M_AXI $m_dma

    # provide M_ARCH, M_TAPASCO, M_INTC and connect to $qdma_desc/S_AXI_CTRL
    # create smartconnect (1 slave, 4 master, 2 clocks [host+design])
    set host_sc [tapasco::ip::create_axi_sc "host_sc" 1 4 2]
    connect_bd_intf_net $host_sc/S00_AXI $qdma/M_AXI_BRIDGE
    connect_bd_intf_net $host_sc/M00_AXI $m_arch
    connect_bd_intf_net $host_sc/M01_AXI $m_tapasco
    connect_bd_intf_net $host_sc/M02_AXI $m_intc
    # connect_bd_intf_net $host_sc/M03_AXI $qdma_desc/S_AXI_CTRL
    connect_bd_intf_net $host_sc/M03_AXI $m_desc_gen
    connect_bd_net $pcie_aclk [get_bd_pins $host_sc/aclk]
    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] [get_bd_pins $host_sc/aclk1]

    connect_bd_net [get_bd_pin $qdma_desc/trigger_reset_cycle] [get_bd_pin $qdma_conf/start_reset]
    connect_bd_net [get_bd_pin $qdma_conf/dma_resetn] [get_bd_pin $qdma/soft_reset_n]
    connect_bd_net [get_bd_pin $qdma/axi_aclk] [get_bd_pin $qdma_desc/aclk] [get_bd_pin $qdma_conf/clk] $pcie_aclk
    connect_bd_net [get_bd_pin $qdma/axi_aresetn] [get_bd_pin $qdma_desc/resetn] [get_bd_pin $qdma_conf/resetn] $pcie_aresetn
  }

  proc create_subsystem_memory {} {
    # memory subsystem implements the NoC logic and Memory Controller
    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_0"]
    set s_axi_dma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA"]
    set s_axi_mem_off [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_0_OFF"]
    set s_axi_dma_off [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA_OFF"]
    set m_axi_mem_off [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_MEM_0_OFF"]
    set m_axi_dma_off [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DMA_OFF"]

    set versal_cips [tapasco::ip::create_versal_cips "versal_cips_0"]
    # set versal_cips [ create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips:3.1 versal_cips_0 ]
    set_property -dict [ list \
      CONFIG.BOOT_MODE {Custom} \
      CONFIG.CLOCK_MODE {REF CLK 33.33 MHz} \
      CONFIG.DDR_MEMORY_MODE {Enable} \
      CONFIG.DEBUG_MODE {JTAG} \
      CONFIG.DESIGN_MODE {1} \
      CONFIG.PS_PMC_CONFIG {\
        CLOCK_MODE {REF CLK 33.33 MHz}\
        DDR_MEMORY_MODE {Connectivity to DDR via NOC}\
        DEBUG_MODE {JTAG}\
        PMC_ALT_REF_CLK_FREQMHZ {33.333}\
        PMC_CRP_EFUSE_REF_CTRL_SRCSEL {IRO_CLK/4}\
        PMC_CRP_HSM0_REF_CTRL_FREQMHZ {33.333}\
        PMC_CRP_HSM1_REF_CTRL_FREQMHZ {133.333}\
        PMC_CRP_LSBUS_REF_CTRL_FREQMHZ {100}\
        PMC_CRP_NOC_REF_CTRL_FREQMHZ {960}\
        PMC_CRP_PL0_REF_CTRL_FREQMHZ {100}\
        PMC_CRP_PL5_REF_CTRL_FREQMHZ {400}\
        PMC_PL_ALT_REF_CLK_FREQMHZ {33.333}\
        PMC_USE_PMC_NOC_AXI0 {1}\
        PS_HSDP_EGRESS_TRAFFIC {JTAG}\
        PS_HSDP_INGRESS_TRAFFIC {JTAG}\
        PS_HSDP_MODE {None}\
        PS_NUM_FABRIC_RESETS {0}\
        PS_USE_FPD_CCI_NOC {1}\
        PS_USE_FPD_CCI_NOC0 {1}\
        PS_USE_NOC_LPD_AXI0 {1}\
        PS_USE_PMCPL_CLK0 {1}\
        PS_USE_PMCPL_CLK1 {0}\
        PS_USE_PMCPL_CLK2 {0}\
        PS_USE_PMCPL_CLK3 {0}\
        PS_USE_PMCPL_IRO_CLK {1}\
        SMON_ALARMS {Set_Alarms_On}\
        SMON_ENABLE_TEMP_AVERAGING {0}\
        SMON_TEMP_AVERAGING_SAMPLES {0}\
      } \
      CONFIG.PS_PMC_CONFIG_APPLIED {1} \
    ] $versal_cips
    if {[llength [info procs get_cips_config]]} {
      # allow for special cips presets
      set_property -dict [get_cips_config] $versal_cips
    }

    # offset to map memory request from QDMA or PEs into address range of memory controllers
    set dma_sc [tapasco::ip::create_axi_sc "dma_sc_0" 1 1 1]
    set dma_offset [tapasco::ip::create_axi_generic_off "dma_offset_0"]
    set_property -dict [list CONFIG.ADDRESS_WIDTH {41} \
      CONFIG.BYTES_PER_WORD {64} \
      CONFIG.HIGHEST_ADDR_BIT {1} \
      CONFIG.ID_WIDTH {4} \
      CONFIG.OVERWRITE_BITS {1} ] $dma_offset
    set arch_offset [tapasco::ip::create_axi_generic_off "arch_offset_0"]
    set_property -dict [list CONFIG.ADDRESS_WIDTH {41} \
      CONFIG.BYTES_PER_WORD {64} \
      CONFIG.HIGHEST_ADDR_BIT {1} \
      CONFIG.ID_WIDTH {6} \
      CONFIG.OVERWRITE_BITS {1} ] $arch_offset

    connect_bd_net $design_aclk [get_bd_pin $arch_offset/aclk]
    connect_bd_net $host_aclk [get_bd_pin $dma_offset/aclk] [get_bd_pin $dma_sc/aclk]
    connect_bd_net $design_aresetn [get_bd_pin $arch_offset/aresetn]
    connect_bd_net $host_p_aresetn [get_bd_pin $dma_offset/aresetn]
    connect_bd_intf_net $s_axi_dma [get_bd_intf_pin $dma_sc/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pin $dma_sc/M00_AXI] [get_bd_intf_pin $dma_offset/S_AXI]
    connect_bd_intf_net [get_bd_intf_pin $dma_offset/M_AXI] $m_axi_dma_off
    connect_bd_intf_net $s_axi_mem [get_bd_intf_pin $arch_offset/S_AXI]
    connect_bd_intf_net [get_bd_intf_pin $arch_offset/M_AXI] $m_axi_mem_off

    set axi_noc [tapasco::ip::create_axi_noc "axi_noc_0"]
    set external_sources {2}
    if {[llength [info procs get_number_mc]]} {
      # always let number of memory controllers be overwritten by platform
      set number_mc [get_number_mc]
    } else {
      # otherwise detect DDR memories from BoardPart
      set number_mc [llength [get_board_components -filter {SUB_TYPE == ddr}]]
      puts "  Configured to $number_mc memory controllers"
    }
    set mc_type DDR
    if {[llength [info procs get_mc_type]]} {
      set mc_type [get_mc_type]
    }
    # Possible values: None, 1, 2, ...
    # port 1: arch
    # port 2: dma
    apply_bd_automation -rule xilinx.com:bd_rule:axi_noc -config [list mc_type $mc_type noc_clk {None} num_axi_bram {None} num_axi_tg {None} num_aximm_ext $external_sources num_mc $number_mc pl2noc_apm {0} pl2noc_cips {1}] $axi_noc
    # 2 external sources still give only one clock, so increase it manually:
    set_property CONFIG.NUM_CLKS [expr [get_property CONFIG.NUM_CLKS $axi_noc]+1] $axi_noc
    if {[llength [info procs get_mc_config]]} {
      set_property -dict [get_mc_config] $axi_noc
    }
    set_property -dict [ list \
      CONFIG.MC_CHAN_REGION0 {DDR_LOW3} \
      CONFIG.MC_CHAN_REGION1 {DDR_LOW3} \
    ] $axi_noc
    if {[llength [get_board_components -quiet -filter {SUB_TYPE == ddr}]] == 0} {
      # if there are no memory components configured, set frequency of clock pins manually to frequency
      for {set i 0} {$i < $number_mc} {incr i} {
        # set frequency  of top level pin
        set_property CONFIG.FREQ_HZ [get_mc_clk_freq] [get_bd_intf_ports /sys_clk${i}_0]
      }
    }
    delete_bd_objs [get_bd_intf_nets /memory/Conn2] [get_bd_intf_nets /memory/Conn1]
    delete_bd_objs [get_bd_intf_pins /memory/S01_AXI] [get_bd_intf_pins /memory/S00_AXI]
    delete_bd_objs [get_bd_intf_nets /S01_AXI_1] [get_bd_intf_nets /S00_AXI_1]
    delete_bd_objs [get_bd_intf_ports /S01_AXI] [get_bd_intf_ports /S00_AXI]
    delete_bd_objs [get_bd_nets aclk1_0_1] [get_bd_ports /aclk1_0]
    delete_bd_objs [get_bd_nets /memory/aclk1_0_1] [get_bd_pins /memory/aclk1_0]
    # S00_AXI -> S_MEM_0
    # S01_AXI -> S_DMA
    connect_bd_intf_net $s_axi_mem_off $axi_noc/S00_AXI
    connect_bd_intf_net $s_axi_dma_off $axi_noc/S01_AXI
    connect_bd_net $design_aclk [get_bd_pin $axi_noc/aclk1]
    connect_bd_net $host_aclk [get_bd_pin $axi_noc/aclk7]
    set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S02_AXI}] [get_bd_pins $axi_noc/aclk0]
    set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S00_AXI}] [get_bd_pins $axi_noc/aclk1]
    set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S01_AXI}] [get_bd_pins $axi_noc/aclk7]
  }

  proc create_subsystem_intc {} {
    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    set s_axi [create_bd_intf_pin -mode Slave -vlnv [tapasco::ip::get_vlnv "aximm_intf"] "S_INTC"]

    set int_in [::tapasco::ip::create_interrupt_in_ports]
    set int_list [::tapasco::ip::get_interrupt_list]
    set int_mapping [list]

    puts "Starting mapping of interrupts $int_list"

    set int_design_total 0
    set int_design 0
    set int_host 0

    set design_concats_last [tapasco::ip::create_xlconcat "int_cc_design_0" 32]
    set design_concats [list $design_concats_last]
    set host_concat [tapasco::ip::create_xlconcat "int_cc_host" 4]

    foreach {name clk} $int_list port $int_in {
      puts "Connecting ${name} (Clk: ${clk}) to ${port}"
      if {$clk == "host"} {
        error "no host interrupts allowed on versal"
        connect_bd_net ${port} [get_bd_pins ${host_concat}/In${int_host}]

        lappend int_mapping $int_host

        incr int_host
      } elseif {$clk == "design"} {
        if { $int_design >= 32 } {
          set n [llength $design_concats]
          set design_concats_last [tapasco::ip::create_xlconcat "int_cc_design_${n}" 32]

          lappend design_concats $design_concats_last

          set int_design 0
        }
        connect_bd_net ${port} [get_bd_pins ${design_concats_last}/In${int_design}]

        lappend int_mapping [expr 4 + $int_design_total]

        incr int_design
        incr int_design_total
      } else {
        error "Memory interrupts not supported"
      }
    }

    ::tapasco::ip::set_interrupt_mapping $int_mapping

    if {[llength $design_concats] > 1} {
      set cntr 0
      set design_concats_last [tapasco::ip::create_xlconcat "int_cc_design_merge" [llength $design_concats]]
      foreach con $design_concats {
        connect_bd_net [get_bd_pins $con/dout] [get_bd_pins ${design_concats_last}/In${cntr}]
        incr cntr
      }
    }

    set qdma_intr_ctrl [tapasco::ip::create_qdma_intr_ctrl "QDMAIntrCtrl_0"]

    connect_bd_intf_net $qdma_intr_ctrl/S_AXI $s_axi

    connect_bd_net [get_bd_pins ${design_concats_last}/dout] [get_bd_pins $qdma_intr_ctrl/interrupt_design] 

    connect_bd_net $design_aclk [get_bd_pins $qdma_intr_ctrl/design_clk]
    connect_bd_net $design_aresetn [get_bd_pins $qdma_intr_ctrl/design_rst]
    connect_bd_net $host_aclk [get_bd_pins $qdma_intr_ctrl/S_AXI_aclk]
    connect_bd_net $host_p_aresetn [get_bd_pins $qdma_intr_ctrl/S_AXI_aresetn]

    connect_bd_intf_net $qdma_intr_ctrl/usr_irq /host/qdma_0/usr_irq
  }

  proc get_pe_base_address {} {
    return 0x02000000;
  }

  proc get_address_map {{pe_base ""}} {
    set max32 [expr "1 << 32"]
    set max64 [expr "1 << 64"]
    if {$pe_base == ""} { set pe_base [get_pe_base_address] }
    set peam [::arch::get_address_map $pe_base]
    set extra_masters_t [tapasco::call_plugins "post-address-map"]
    set extra_masters [dict create ]
    foreach {key value} $extra_masters_t {
        dict set extra_masters $key $value
    }
    puts "Computing addresses for masters ..."
    set masters [::tapasco::get_aximm_interfaces [get_bd_cells -filter "PATH !~ [::tapasco::subsystem::get arch]/*"]]
    foreach m $masters {
      switch -glob [get_property NAME $m] {
        "M_INTC"      { foreach {base stride range comp} [list [expr [get_platform_base_address]+0x20000] 0x10000 0                "PLATFORM_COMPONENT_INTC0" ] {} }
        "M_TAPASCO"   { foreach {base stride range comp} [list [get_platform_base_address]                0x10000 0                "PLATFORM_COMPONENT_STATUS"] {} }
        "M_DESC_GEN"  { foreach {base stride range comp} [list [expr [get_platform_base_address]+0x10000] 0x10000 0                "PLATFORM_COMPONENT_DMA0"  ] {} }
        "M_DMA"       { foreach {base stride range comp} [list 0                                          0       [get_total_memory_size] ""                         ] {} }
        "M_DMA_OFF"   { foreach {base stride range comp} [list [expr "1 << 40"]                           0       [get_total_memory_size] ""                         ] {} }
        "M_MEM_0"     { foreach {base stride range comp} [list 0                                          0       [get_total_memory_size] ""                         ] {} }
        "M_MEM_0_OFF" { foreach {base stride range comp} [list [expr "1 << 40"]                           0       [get_total_memory_size] ""                         ] {} }
        "M_ARCH"     { set base "skip" }
        default      { if { [dict exists $extra_masters [get_property NAME $m]] } {
                          set l [dict get $extra_masters [get_property NAME $m]]
                          set base [lindex $l 0]
                          set stride [lindex $l 1]
                          set range [lindex $l 2]
                          set comp [lindex $l 3]
                          puts "Special address for [get_property NAME $m] base: $base stride: $stride range: $range comp: $comp"
                        } else {
                            error "No address defined for [get_property NAME $m], please make sure to define one in post-address-map plugin"
                        }
                    }
      }
      if {$base != "skip"} { set peam [addressmap::assign_address $peam $m $base $stride $range $comp] }
    }
    return $peam
  }

  proc get_ignored_segments {} {
    set ignored [list]
    for {set i 2} {$i < 9} {incr i} {
      # skip i = 0, 1 (those are managed by tapasco)
      for {set j 0} {$j < 4} {incr j} {
        lappend ignored "/memory/axi_noc_0/S0${i}_AXI/C${j}_DDR_LOW3"
        for {set k 0} {$k < 4} {incr k} {
          lappend ignored "/memory/axi_noc_0/S0${i}_AXI/C${j}_DDR_LOW3x${k}"
        }
      }
    }
    return $ignored
  }

