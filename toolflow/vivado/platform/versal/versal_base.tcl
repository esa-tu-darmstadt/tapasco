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

    set pcie_aclk [create_bd_pin -type "clk" -dir "O" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "O" "pcie_aresetn"]

    set qdma [tapasco::ip::create_qdma qdma_0]
    apply_bd_automation -rule xilinx.com:bd_rule:qdma -config { axi_strategy {max_data} link_speed {3} link_width {16} pl_pcie_cpm {PL-PCIE}} $qdma
    set_property -dict [list \
      CONFIG.mode_selection {Advanced} \
      CONFIG.dma_intf_sel_qdma {AXI_MM} \
      CONFIG.en_axi_st_qdma {false} \
      CONFIG.pcie_blk_locn {X0Y2} \
      CONFIG.testname {mm} \
      CONFIG.axilite_master_en {false} \
      CONFIG.axist_bypass_en {true} \
      CONFIG.adv_int_usr {true} \
      CONFIG.dsc_byp_mode {Descriptor_bypass_and_internal} \
      CONFIG.pf0_device_id {7038} \
      CONFIG.pf0_bar2_size_qdma {128} \
      CONFIG.pf0_bar2_type_qdma {AXI_Bridge_Master} \
      CONFIG.pf0_pciebar2axibar_2 [get_platform_base_address] \
      CONFIG.PF0_MSIX_CAP_TABLE_SIZE_qdma {01F} \
    ] $qdma

    # TODO: Make configuration device dependent

    set QDMADesc [create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:QDMADescriptorGenerator:1.0 QDMADescriptorGenera_0]
    connect_bd_intf_net $QDMADesc/c2h_byp_in $qdma/c2h_byp_in_mm
    connect_bd_intf_net $QDMADesc/h2c_byp_in $qdma/h2c_byp_in_mm
    connect_bd_intf_net $QDMADesc/tm_dsc_sts $qdma/tm_dsc_sts
    connect_bd_intf_net $QDMADesc/qsts_out $qdma/qsts_out
    connect_bd_intf_net $QDMADesc/c2h_byp_out $qdma/c2h_byp_out
    connect_bd_intf_net $QDMADesc/h2c_byp_out $qdma/h2c_byp_out

    set QDMAIntrVecCtrl [create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:QDMAIntrVecCtrl:1.0 QDMAIntrVecCtrl_0]
    connect_bd_net [get_bd_pin $QDMAIntrVecCtrl/numvec_done] [get_bd_pin $qdma/numvec_done]
    connect_bd_net [get_bd_pin $QDMAIntrVecCtrl/numvec_valid] [get_bd_pin $qdma/numvec_valid]
    connect_bd_net [get_bd_pin $QDMAIntrVecCtrl/trigger_config_irqs] [get_bd_pin $QDMADesc/config_irqs]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_pf0] [get_bd_pins $qdma/msix_vectors_per_pf0]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_pf1] [get_bd_pins $qdma/msix_vectors_per_pf1]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_pf2] [get_bd_pins $qdma/msix_vectors_per_pf2]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_pf3] [get_bd_pins $qdma/msix_vectors_per_pf3]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_vfg0] [get_bd_pins $qdma/msix_vectors_per_vfg0]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_vfg1] [get_bd_pins $qdma/msix_vectors_per_vfg1]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_vfg2] [get_bd_pins $qdma/msix_vectors_per_vfg2]
    connect_bd_net [get_bd_pins $QDMAIntrVecCtrl/msix_vectors_per_vfg3] [get_bd_pins $qdma/msix_vectors_per_vfg3]

    connect_bd_intf_net $qdma/M_AXI $m_dma

    # provide M_ARCH, M_TAPASCO, M_INTC and connect to $QDMADesc/S_AXI_CTRL
    # create smartconnect (1 slave, 4 master, 2 clocks [host+design])
    set host_sc [tapasco::ip::create_axi_sc "host_sc" 1 4 2]
    connect_bd_intf_net $host_sc/S00_AXI $qdma/M_AXI_BRIDGE
    connect_bd_intf_net $host_sc/M00_AXI $m_arch
    connect_bd_intf_net $host_sc/M01_AXI $m_tapasco
    connect_bd_intf_net $host_sc/M02_AXI $m_intc
    connect_bd_intf_net $host_sc/M03_AXI $QDMADesc/S_AXI_CTRL
    connect_bd_net $pcie_aclk [get_bd_pins $host_sc/aclk]
    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] [get_bd_pins $host_sc/aclk1]

    connect_bd_net [get_bd_pin $QDMADesc/dma_resetn] [get_bd_pin $qdma/soft_reset_n]
    connect_bd_net [get_bd_pin $qdma/axi_aclk] [get_bd_pin $QDMADesc/aclk] [get_bd_pin $QDMAIntrVecCtrl/clk] $pcie_aclk
    connect_bd_net [get_bd_pin $qdma/axi_aresetn] [get_bd_pin $QDMADesc/resetn] [get_bd_pin $QDMAIntrVecCtrl/resetn] $pcie_aresetn
  }

  proc create_subsystem_memory {} {
    # memory subsystem implements the NoC logic and Memory Controller
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
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

    set axi_noc [tapasco::ip::create_axi_noc "axi_noc_0"]
    set external_sources {2}
    # Possible values: None, 1, 2, ...
    # port 1: arch
    # port 2: dma
    apply_bd_automation -rule xilinx.com:bd_rule:axi_noc -config [list mc_type {DDR} noc_clk {None} num_axi_bram {None} num_axi_tg {None} num_aximm_ext $external_sources num_mc [get_number_mc] pl2noc_apm {0} pl2noc_cips {1}] $axi_noc
    # 2 external sources still give only one clock, so increase it manually:
    set_property CONFIG.NUM_CLKS [expr [get_property CONFIG.NUM_CLKS $axi_noc]+1] $axi_noc
    set_property -dict [get_mc_config] $axi_noc
    for {set i 0} {$i < [get_number_mc]} {incr i} {
      # set frequency  of top level pin
      set_property CONFIG.FREQ_HZ 100000000 [get_bd_intf_ports /sys_clk${i}_0]
    }
    delete_bd_objs [get_bd_intf_nets /memory/Conn2] [get_bd_intf_nets /memory/Conn1]
    delete_bd_objs [get_bd_intf_pins /memory/S01_AXI] [get_bd_intf_pins /memory/S00_AXI]
    delete_bd_objs [get_bd_intf_nets /S01_AXI_1] [get_bd_intf_nets /S00_AXI_1]
    delete_bd_objs [get_bd_intf_ports /S01_AXI] [get_bd_intf_ports /S00_AXI]
    delete_bd_objs [get_bd_nets aclk1_0_1] [get_bd_ports /aclk1_0]
    delete_bd_objs [get_bd_nets /memory/aclk1_0_1] [get_bd_pins /memory/aclk1_0]
    # S00_AXI -> S_MEM_0
    # S01_AXI -> S_DMA
    set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_0"]
    set s_axi_dma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA"]
    connect_bd_intf_net $s_axi_mem $axi_noc/S00_AXI
    connect_bd_intf_net $s_axi_dma $axi_noc/S01_AXI
    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] [get_bd_pin $axi_noc/aclk1]
    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] [get_bd_pin $axi_noc/aclk7]
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

    set QDMAIntrCtrl [create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:QDMAIntrCtrl:1.0 QDMAIntrCtrl_0]

    connect_bd_intf_net $QDMAIntrCtrl/S_AXI $s_axi

    connect_bd_net [get_bd_pins ${design_concats_last}/dout] [get_bd_pins $QDMAIntrCtrl/interrupt_design] 

    connect_bd_net $design_aclk [get_bd_pins $QDMAIntrCtrl/design_clk]
    connect_bd_net $design_aresetn [get_bd_pins $QDMAIntrCtrl/design_rst]
    connect_bd_net $host_aclk [get_bd_pins $QDMAIntrCtrl/S_AXI_aclk]
    connect_bd_net $host_p_aresetn [get_bd_pins $QDMAIntrCtrl/S_AXI_aresetn]

    connect_bd_intf_net $QDMAIntrCtrl/usr_irq /host/qdma_0/usr_irq
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
    lappend masters [get_bd_intf_pin /host/host_sc/M03_AXI]
    foreach m $masters {
      switch -glob [get_property NAME $m] {
        "M_INTC"    { foreach {base stride range comp} [list                  0x00020000 0x10000 0 "PLATFORM_COMPONENT_INTC0"] {} }
        "M_TAPASCO" { foreach {base stride range comp} [list [get_platform_base_address] 0x10000 0 "PLATFORM_COMPONENT_STATUS"] {} }
        "M03_AXI"   { foreach {base stride range comp} [list [expr [get_platform_base_address]+0x30000] 0x10000 0 "PLATFORM_COMPONENT_QDMA"] {} }
        "M_DMA"     { foreach {base stride range comp} [list [expr [get_platform_base_address]+0x40000] 0x10000 0 "PLATFORM_COMPONENT_DMA"] {} }
        "M_ARCH"    { set base "skip" }
        default     { if { [dict exists $extra_masters [get_property NAME $m]] } {
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
    lappend ignored "/memory/axi_noc_0/S00_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S01_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S02_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S03_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S04_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S05_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S06_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S07_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S08_AXI/C0_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S00_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S01_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S02_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S03_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S04_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S05_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S06_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S07_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S08_AXI/C1_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S00_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S01_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S02_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S03_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S04_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S05_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S06_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S07_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S08_AXI/C2_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S00_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S01_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S02_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S03_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S04_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S05_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S06_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S07_AXI/C3_DDR_LOW3x4"
    lappend ignored "/memory/axi_noc_0/S08_AXI/C3_DDR_LOW3x4"
    return $ignored
  }

