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

  if {[::tapasco::vivado_is_newer "2021.2"] != 1 } {
    puts "Only Vivado 2021.2 and newer is supported for Versal devices."
    exit 1
  }

  # set PCIe width to X16 if not specified by platform
  if { ! [info exists pcie_width] } {
    puts "No PCIe width defined. Assuming x16..."
    set pcie_width "16"
  } else {
    puts "Using PCIe width $pcie_width."
  }

  if { ! [info exists pcie_speed] } {
    puts "No PCIe speed defined. Assuming 8.0 GT/s"
    set pcie_speed "8.0"
  } else {
    puts "Using PCIe speed $pcie_speed GT/s"
  }

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/versal/plugins" "*.tcl"] {
    source -notrace $f
  }

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/${platform_dirname}/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    # return [list [::tapasco::get_platform_num_slots]]
    set masters [list]
    for {set i 0} {$i < 28} {incr i} {
      set masters [lappend masters 5]
    }
    return $masters
  }

  proc number_of_interrupt_controllers {} {
    return 1
  }

  proc get_platform_base_address {} {
    return 0x20100000000
  }

  proc get_platform_base_address_status_core {} {
    return 0x0
  }

  proc create_subsystem_clocks_and_resets {} {
    # PCIe and PL clocks as input
    set pl_clk [create_bd_pin -type "clk" -dir "I" "pl0_ref_clk"]
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
    connect_bd_net $pl_clk [get_bd_pins $design_clk_wiz/clk_in1]

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
    # host subsystem implements the CIPS including DMA
    variable pcie_width
    variable pcie_speed

    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    set pl_clk [create_bd_pin -type "clk" -dir "O" "pl0_ref_clk"]
    set pcie_aclk [create_bd_pin -type "clk" -dir "O" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "O" "pcie_aresetn"]

    set s_axi_desc_gen [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DESC_GEN"]

    set versal_cips [tapasco::ip::create_versal_cips "versal_cips_0"]

    # create NoC here and move it to memory subsystem later
    set axi_noc [tapasco::ip::create_axi_noc "axi_noc_0"]
    set external_sources {None}
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
    apply_bd_automation -rule xilinx.com:bd_rule:axi_noc -config [list mc_type $mc_type noc_clk {None} num_axi_bram {None} num_axi_tg {None} num_aximm_ext $external_sources num_mc $number_mc pl2noc_apm {0} pl2noc_cips {1}] $axi_noc

    # add AXI ports and clocks for CPM ports
    set_property CONFIG.NUM_SI [expr [get_property CONFIG.NUM_SI $axi_noc]+2] $axi_noc
    set_property CONFIG.NUM_CLKS [expr [get_property CONFIG.NUM_CLKS $axi_noc]+2] $axi_noc

    # load MC config
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

    # configure CIPS after NoC so that Vivado does not remove ports during BD automation
    set link_width "X$pcie_width"
    set link_speed "${pcie_speed}_GT/s"
    set_property -dict [list \
      CONFIG.CLOCK_MODE {REF CLK 33.33 MHz} \
      CONFIG.CPM_CONFIG [list \
        CPM_PCIE0_DMA_INTF {AXI_MM_and_AXI_Stream} \
        CPM_PCIE0_DSC_BYPASS_RD {1} \
        CPM_PCIE0_DSC_BYPASS_WR {1} \
        CPM_PCIE0_FUNCTIONAL_MODE {QDMA} \
        CPM_PCIE0_LANE_REVERSAL_EN {1} \
        CPM_PCIE0_MAX_LINK_SPEED $link_speed \
        CPM_PCIE0_MODES {DMA} \
        CPM_PCIE0_MODE_SELECTION {Advanced} \
        CPM_PCIE0_MSI_X_OPTIONS {MSI-X_Internal} \
        CPM_PCIE0_PF0_BAR0_QDMA_64BIT {1} \
        CPM_PCIE0_PF0_BAR0_QDMA_SCALE {Megabytes} \
        CPM_PCIE0_PF0_BAR0_QDMA_SIZE {64} \
        CPM_PCIE0_PF0_BAR0_QDMA_TYPE {AXI_Bridge_Master} \
        CPM_PCIE0_PF0_BAR2_QDMA_64BIT {1} \
        CPM_PCIE0_PF0_BAR2_QDMA_ENABLED {1} \
        CPM_PCIE0_PF0_BAR2_QDMA_TYPE {DMA} \
        CPM_PCIE0_PF0_PCIEBAR2AXIBAR_QDMA_0 {0x0000020100000000} \
        CPM_PCIE0_PF0_CFG_DEV_ID {B03F} \
        CPM_PCIE0_PF0_MSIX_CAP_TABLE_SIZE {01F} \
        CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH $link_width \
      ] \
      CONFIG.DDR_MEMORY_MODE {Enable} \
      CONFIG.DEBUG_MODE {JTAG} \
      CONFIG.PS_PMC_CONFIG { \
        CLOCK_MODE {REF CLK 33.33 MHz} \
        DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
        DEBUG_MODE {JTAG} \
        DESIGN_MODE {1} \
        PCIE_APERTURES_DUAL_ENABLE {0} \
        PCIE_APERTURES_SINGLE_ENABLE {1} \
        PMC_ALT_REF_CLK_FREQMHZ {33.333} \
        PMC_CRP_EFUSE_REF_CTRL_SRCSEL {IRO_CLK/4} \
        PMC_CRP_HSM0_REF_CTRL_FREQMHZ {33.333} \
        PMC_CRP_HSM1_REF_CTRL_FREQMHZ {133.333} \
        PMC_CRP_LSBUS_REF_CTRL_FREQMHZ {100} \
        PMC_CRP_NOC_REF_CTRL_FREQMHZ {960} \
        PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
        PMC_CRP_PL5_REF_CTRL_FREQMHZ {400} \
        PMC_PL_ALT_REF_CLK_FREQMHZ {33.333} \
        PMC_USE_PMC_NOC_AXI0 {1} \
        PS_BOARD_INTERFACE {Custom} \
        PS_HSDP_EGRESS_TRAFFIC {JTAG} \
        PS_HSDP_INGRESS_TRAFFIC {JTAG} \
        PS_HSDP_MODE {NONE} \
        PS_PCIE1_PERIPHERAL_ENABLE {1} \
        PS_PCIE2_PERIPHERAL_ENABLE {0} \
        PS_PCIE_EP_RESET1_IO {PMC_MIO 38} \
        PS_PCIE_RESET {ENABLE 1} \
        PS_USE_FPD_CCI_NOC {1} \
        PS_USE_FPD_CCI_NOC0 {1} \
        PS_USE_NOC_LPD_AXI0 {1} \
        PS_USE_PMCPL_CLK0 {1} \
        PS_USE_PMCPL_IRO_CLK {1} \
        SMON_ALARMS {Set_Alarms_On} \
        SMON_ENABLE_TEMP_AVERAGING {0} \
        SMON_TEMP_AVERAGING_SAMPLES {0} \
      } \
    ] $versal_cips

    if {[llength [info procs get_cips_config]]} {
      # allow for special cips presets
      set_property -dict [get_cips_config] $versal_cips
    }

    make_bd_intf_pins_external [get_bd_intf_pins $versal_cips/gt_refclk0]
    make_bd_intf_pins_external [get_bd_intf_pins $versal_cips/PCIE0_GT]
    connect_bd_net [get_bd_pins $versal_cips/pl0_ref_clk] $pl_clk
    connect_bd_net [get_bd_pins $versal_cips/pcie0_user_clk] $pcie_aclk
    connect_bd_net [get_bd_pins $versal_cips/dma0_axi_aresetn] $pcie_aresetn

    set desc_gen [tapasco::ip::create_qdma_desc_gen "desc_gen_0"]
    connect_bd_net $host_aclk [get_bd_pins $desc_gen/aclk]
    connect_bd_net $host_p_aresetn [get_bd_pins $desc_gen/resetn]
    connect_bd_intf_net $s_axi_desc_gen [get_bd_intf_pins $desc_gen/S_AXI_CTRL]
    connect_bd_intf_net [get_bd_intf_pins $versal_cips/dma0_c2h_byp_out] [get_bd_intf_pins $desc_gen/c2h_byp_out]
    connect_bd_intf_net [get_bd_intf_pins $versal_cips/dma0_h2c_byp_out] [get_bd_intf_pins $desc_gen/h2c_byp_out]
    connect_bd_intf_net [get_bd_intf_pins $versal_cips/dma0_tm_dsc_sts] [get_bd_intf_pins $desc_gen/tm_dsc_sts]
    connect_bd_intf_net [get_bd_intf_pins $desc_gen/c2h_byp_in] [get_bd_intf_pins $versal_cips/dma0_c2h_byp_in_mm]
    connect_bd_intf_net [get_bd_intf_pins $desc_gen/h2c_byp_in] [get_bd_intf_pins $versal_cips/dma0_h2c_byp_in_mm]

    connect_bd_net [get_bd_pins $desc_gen/dma_resetn] [get_bd_pins $versal_cips/dma0_soft_resetn]

    # FIXME do not hardcode ports?
    connect_bd_intf_net [get_bd_intf_pins $versal_cips/CPM_PCIE_NOC_0] [get_bd_intf_pins $axi_noc/S06_AXI]
    connect_bd_intf_net [get_bd_intf_pins $versal_cips/CPM_PCIE_NOC_1] [get_bd_intf_pins $axi_noc/S07_AXI]
    connect_bd_net [get_bd_pins $versal_cips/cpm_pcie_noc_axi0_clk] [get_bd_pins $axi_noc/aclk6]
    connect_bd_net [get_bd_pins $versal_cips/cpm_pcie_noc_axi1_clk] [get_bd_pins $axi_noc/aclk7]
  }

  proc create_subsystem_memory {} {
    # memory subsystem implements NoC logic and Memory Controller
    set num_masters [llength [::arch::get_masters]]

    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    set m_axi_arch [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_ARCH"]
    set m_axi_tapasco [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_TAPASCO"]
    set m_axi_intc [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_INTC"]
    set m_axi_desc_gen [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DESC_GEN"]

    # add ports according to actual number of arch masters
    set axi_mem_slaves [list]
    for {set i 0} {$i < $num_masters} {incr i} {
      set s_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_$i"]
      lappend axi_mem_slaves $s_mem
    }

    # move NoC from host to memory subsystem
    move_bd_cells [current_bd_instance .] [get_bd_cells /host/axi_noc_0]
    set axi_noc [get_bd_cells axi_noc_0]

    # add AXI ports and clocks for PE interconnect trees and CPM ports
    set_property CONFIG.NUM_SI [expr [get_property CONFIG.NUM_SI $axi_noc]+$num_masters] $axi_noc
    set_property CONFIG.NUM_MI [expr [get_property CONFIG.NUM_MI $axi_noc]+1] $axi_noc
    set_property CONFIG.NUM_CLKS [expr [get_property CONFIG.NUM_CLKS $axi_noc]+2] $axi_noc

    # Configure NoC ports and connections for CPM and ARCH
    set_property -dict [list CONFIG.CATEGORY {ps_pcie} \
      CONFIG.CONNECTIONS { \
        MC_0 {read_bw {10000} write_bw {10000} read_avg_burst {4} write_avg_burst {4}} \
        M00_AXI {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}}
    ] [get_bd_intf_pins $axi_noc/S06_AXI]
    set_property -dict [list CONFIG.CATEGORY {ps_pcie} \
      CONFIG.CONNECTIONS { \
        M00_AXI {read_bw {1} write_bw {1} read_avg_burst {4} write_avg_burst {4}}} \
    ] [get_bd_intf_pins $axi_noc/S07_AXI]
    set_property CONFIG.ASSOCIATED_BUSIF S06_AXI [get_bd_pins $axi_noc/aclk6]
    set_property CONFIG.ASSOCIATED_BUSIF S07_AXI [get_bd_pins $axi_noc/aclk7]
    set_property CONFIG.ASSOCIATED_BUSIF M00_AXI [get_bd_pins $axi_noc/aclk8]

    # create NoC ports for arch slaves, use round robin to distribute evenly to MC channels
    set mc_port 1;
    for {set i 0} {$i < $num_masters} {incr i} {
      set axi_port [format "S%02s_AXI" [expr "$i + 8"]]
      set_property -dict [list CONFIG.CATEGORY {pl} \
        CONFIG.CONNECTIONS "MC_$mc_port {read_bw {1000} write_bw {1000} read_avg_burst {4} write_avg_burst {4}}" \
      ] [get_bd_intf_pins $axi_noc/$axi_port]
      if {$mc_port == 3} {
        set mc_port 0
      } else {
        incr mc_port
      }
    }

    # offset(s) to map memory request from PEs into address range of memory controllers
    set arch_offset_cores [list]
    for {set i 0} {$i < $num_masters} {incr i} {
      set arch_offset [tapasco::ip::create_axi_generic_off "arch_offset_$i"]
      set_property -dict [list CONFIG.ADDRESS_WIDTH {41} \
        CONFIG.BYTES_PER_WORD {64} \
        CONFIG.HIGHEST_ADDR_BIT {1} \
        CONFIG.ID_WIDTH {6} \
        CONFIG.OVERWRITE_BITS {1} ] $arch_offset
      lappend arch_offset_cores $arch_offset
    }

    foreach core $arch_offset_cores intf $axi_mem_slaves {
      connect_bd_net $design_aclk [get_bd_pins $core/aclk]
      connect_bd_net $design_aresetn [get_bd_pins $core/aresetn]
      connect_bd_intf_net $intf $core/S_AXI
    }

    set host_sc [tapasco::ip::create_axi_sc "host_sc" 1 4 2]
    connect_bd_net $host_aclk [get_bd_pins $host_sc/aclk]
    connect_bd_net $design_aclk [get_bd_pins $host_sc/aclk1]
    connect_bd_intf_net [get_bd_intf_pins $axi_noc/M00_AXI] [get_bd_intf_pins $host_sc/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins $host_sc/M00_AXI] $m_axi_arch
    connect_bd_intf_net [get_bd_intf_pins $host_sc/M01_AXI] $m_axi_tapasco
    connect_bd_intf_net [get_bd_intf_pins $host_sc/M02_AXI] $m_axi_intc
    connect_bd_intf_net [get_bd_intf_pins $host_sc/M03_AXI] $m_axi_desc_gen

    # FIXME do not hardcode ports?
    for {set i 0} {$i < $num_masters} {incr i} {
      set axi_port [format "S%02s_AXI" [expr "$i + 8"]]
      connect_bd_intf_net [lindex $arch_offset_cores $i]/M_AXI [get_bd_intf_pins $axi_noc/$axi_port]
    }
    connect_bd_net $host_aclk [get_bd_pins $axi_noc/aclk8]
    connect_bd_net $design_aclk [get_bd_pins $axi_noc/aclk9]
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

    connect_bd_intf_net $qdma_intr_ctrl/usr_irq /host/versal_cips_0/dma0_usr_irq
  }

  proc get_pe_base_address {} {
    return 0x20102000000;
  }

  proc get_pe_base_address_status_core {} {
    return 0x02000000
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
        "M_ARCH"     { set base "skip" }
        default      { if { [dict exists $extra_masters [get_property NAME $m]] } {
                          set l [dict get $extra_masters [get_property NAME $m]]
                          set base [lindex $l 0]
                          set stride [lindex $l 1]
                          set range [lindex $l 2]
                          set comp [lindex $l 3]
                          puts "Special address for [get_property NAME $m] base: $base stride: $stride range: $range comp: $comp"
                        } else {
                            puts "No address defined for [get_property NAME $m], please make sure to define one in post-address-map plugin or set interface on ignore list"
                            set base "skip"
                        }
                    }
      }
      if {$base != "skip"} { set peam [addressmap::assign_address $peam $m $base $stride $range $comp] }
    }
    return $peam
  }

  proc get_ignored_segments {} {
    set num_masters [llength [::arch::get_masters]]
    set ignored [list]
    for {set i 0} {$i < [expr "$num_masters + 8"]} {incr i} {
      set axi_port [format "S%02s_AXI" $i]
      for {set j 0} {$j < 4} {incr j} {
        lappend ignored "/memory/axi_noc_0/${axi_port}/C${j}_DDR_LOW3"
        for {set k 1} {$k < 5} {incr k} {
          lappend ignored "/memory/axi_noc_0/${axi_port}/C${j}_DDR_LOW3x${k}"
        }
      }
    }
    return $ignored
  }

  # add all arch memory interfaces to address map
  proc versal_extra_masters {{args {}}} {
    set num_masters [llength [::arch::get_masters]]
    for {set i 0} {$i < $num_masters} {incr i} {
      set axi_port [format "S%02s_AXI" [expr "$i + 8"]]
      set name [format "M_MEM_$i"]
      lappend args $name [list 0 0 [get_total_memory_size] ""]
    }
    return $args
  }

  tapasco::register_plugin "platform::versal_extra_masters" "post-address-map"