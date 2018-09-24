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
# @file     pcie_base.tcl
# @brief    Functions common to all TCL platforms
# @author   J. A. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
#

  namespace export create
  namespace export max_masters
  namespace export create_subsystem_clocks_and_resets
  namespace export create_subsystem_host
  namespace export create_subsystem_memory
  namespace export create_subsystem_intc
  namespace export create_subsystem_tapasco

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/pcie/plugins" "*.tcl"] {
    source -notrace $f
  }

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/${platform_dirname}/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list [::tapasco::get_platform_num_slots]]
  }

  proc number_of_interrupt_controllers {} {
    return 1
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
    foreach m [::tapasco::get_aximm_interfaces [get_bd_cells -filter "PATH !~ [::tapasco::subsystem::get arch]/*"]] {
      switch -glob [get_property NAME $m] {
        "M_DMA"     { foreach {base stride range comp} [list 0x00300000 0x10000 0      "PLATFORM_COMPONENT_DMA0"] {} }
        "M_INTC"    { foreach {base stride range comp} [list 0x00500000 0x10000 0      "PLATFORM_COMPONENT_INTC0"] {} }
        "M_MSIX"    { foreach {base stride range comp} [list 0          0       $max64 "PLATFORM_COMPONENT_MSIX0"] {} }
        "M_TAPASCO" { foreach {base stride range comp} [list 0x02800000 0       0      "PLATFORM_COMPONENT_STATUS"] {} }
        "M_HOST"    { foreach {base stride range comp} [list 0          0       $max64 ""] {} }
        "M_MEM_0"    { foreach {base stride range comp} [list 0          0       $max64 ""] {} }
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

  # Setup the clock network.
  proc platform_connect_clock {clock_pin} {
    puts "Connecting clocks ..."

    set clk_inputs [get_bd_pins -of_objects [get_bd_cells -filter {NAME != "mig_7series_0" && NAME != "proc_sys_reset_0"&& NAME != "axi_pcie3_0" && NAME != "pcie_ic"}] -filter { TYPE == "clk" && DIR == "I" && NAME != "refclk"}]
    connect_bd_net $clock_pin $clk_inputs
  }

  # Create interrupt controller subsystem:
  # Consists of AXI_INTC IP cores (as many as required), which are connected by an internal
  # AXI Interconnect (S_AXI port), as well as an PCIe interrupt controller IP which can be
  # connected to the PCIe bridge (required ports external).
  # @param irqs List of the interrupts from the threadpool.
  proc create_subsystem_intc {} {
    set irqs [arch::get_irqs]
    puts "Connecting [llength $irqs] interrupts .."
    # create hierarchical ports
    set s_axi [create_bd_intf_pin -mode Slave -vlnv [tapasco::ip::get_vlnv "aximm_intf"] "S_INTC"]
    set msix_interface [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:pcie3_cfg_msix_rtl:1.0 "M_MSIX"]
    set aclk [tapasco::subsystem::get_port "host" "clk"]
    set p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set dma_irq_read [create_bd_pin -type "intr" -dir I "dma_irq_read"]
    set dma_irq_write [create_bd_pin -type "intr" -dir I "dma_irq_write"]

    set num_irqs_threadpools [::tapasco::get_platform_num_slots]
    set num_irqs [expr $num_irqs_threadpools + 4]

    set irq_concat_ss [tapasco::ip::create_xlconcat "interrupt_concat" 4]

    # create MSIX interrupt controller
    set msix_intr_ctrl [tapasco::ip::create_msix_intr_ctrl "msix_intr_ctrl"]
    connect_bd_net [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "dout"}] [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "interrupt_pcie"}]

    connect_bd_intf_net $msix_interface [get_bd_intf_pins msix_intr_ctrl/msix]

    connect_bd_net $dma_irq_read [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In0"}]
    connect_bd_net $dma_irq_write [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In1"}]
    puts "Unused Interrupts: 2, 3 are tied to 0"
    set irq_unused [tapasco::ip::create_constant "irq_unused" 1 0]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In2"}]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In3"}]

    set irq_concat_design [tapasco::ip::create_xlconcat "interrupt_concat_design" 4]

    for {set i 0} {$i < 4} {incr i} {
      set port [create_bd_pin -from 31 -to 0 -dir I -type intr "intr_$i"]
      connect_bd_net $port [get_bd_pin -of_objects $irq_concat_design -filter "NAME == In$i"]
    }

    connect_bd_net [get_bd_pin -of_objects $irq_concat_design -filter {NAME == "dout"}] [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "interrupt_design"}]

    # connect internal clocks
    connect_bd_net $aclk [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI_ACLK"}]
    connect_bd_net $design_aclk [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "design_clk"}]
    connect_bd_net $p_aresetn [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI_ARESETN"}]
    connect_bd_net $design_aresetn [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "design_rst"}]

    # connect S_AXI
    connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI"}]
  }

  # Creates the memory subsystem consisting of MIG core for DDR RAM,
  # and a DMA engine which is connected to the MIG and has an
  # external 64bit M_AXI channel toward PCIe.
  proc create_subsystem_memory {} {
    # create hierarchical interface ports
    set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_0"]
    set m_axi_mem [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_HOST"]
    set s_axi_ddma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA"]

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

    set irq_read [create_bd_pin -type "intr" -dir "O" "dma_irq_read"]
    set irq_write [create_bd_pin -type "intr" -dir "O" "dma_irq_write"]

    # create instances of cores: MIG core, DMA, system cache
    set mig [create_mig_core "mig"]

    set dma [tapasco::ip::create_bluedma "dma"]
    connect_bd_net [get_bd_pins $dma/IRQ_read] $irq_read
    connect_bd_net [get_bd_pins $dma/IRQ_write] $irq_write

    set mig_ic [tapasco::ip::create_axi_sc "mig_ic" 2 1]
    tapasco::ip::connect_sc_default_clocks $mig_ic "mem"

    # FIXME this belongs into a plugin
    set cache_en [tapasco::is_feature_enabled "Cache"]
    if {$cache_en} {
      set cf [tapasco::get_feature "Cache"]
      puts "Platform configured w/L2 Cache, implementing ..."
      set cache [tapasco::ip::create_axi_cache "cache_l2" 1 \
          [dict get [tapasco::get_feature "Cache"] "size"] \
          [dict get [tapasco::get_feature "Cache"] "associativity"]]

      # connect mig_ic master to cache_l2
      connect_bd_intf_net [get_bd_intf_pins mig_ic/M00_AXI] [get_bd_intf_pins $cache/S0_AXI_GEN]
      # connect cache_l2 to MIG
      connect_bd_intf_net [get_bd_intf_pins $cache/M_AXI] [get_bd_intf_pins  -regexp mig/(C0_DDR4_)?S_AXI]
    } {
      puts "Platform configured w/o L2 Cache"
      # no cache - connect directly to MIG
      connect_bd_intf_net [get_bd_intf_pins mig_ic/M00_AXI] [get_bd_intf_pins -regexp mig/(C0_DDR4_)?S_AXI]
    }

    # AXI connections:
    # connect dma 32bit to mig_ic
    connect_bd_intf_net [get_bd_intf_pins $dma/M32_AXI] [get_bd_intf_pins mig_ic/S00_AXI]
    # connect DMA 64bit to external port
    connect_bd_intf_net [get_bd_intf_pins $dma/M64_AXI] $m_axi_mem
    # connect second mig_ic slave to external port
    connect_bd_intf_net $s_axi_mem [get_bd_intf_pins mig_ic/S01_AXI]
    # connect DMA S_AXI to external port
    connect_bd_intf_net $s_axi_ddma [get_bd_intf_pins $dma/S_AXI]

    # connect PCIe clock and reset
    connect_bd_net $pcie_aclk [get_bd_pins $dma/m64_axi_aclk] [get_bd_pins $dma/s_axi_aclk]
    connect_bd_net $pcie_p_aresetn [get_bd_pins $dma/m64_axi_aresetn] [get_bd_pins $dma/s_axi_aresetn]

    # connect DDR clock and reset
    set ddr_clk [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk]
    connect_bd_net [tapasco::subsystem::get_port "mem" "clk"] \
      [get_bd_pins $dma/m32_axi_aclk]
    connect_bd_net $ddr_p_aresetn \
      [get_bd_pins $dma/m32_axi_aresetn] \
      [get_bd_pins -regexp mig/(c0_ddr4_)?aresetn]

    # connect external DDR clk/rst output ports
    connect_bd_net $ddr_clk $ddr_aclk

    set design_clk_wiz [tapasco::ip::create_clk_wiz design_clk_wiz]
    set_property -dict [list CONFIG.CLK_OUT1_PORT {design_clk} \
                        CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [tapasco::get_design_frequency] \
                        CONFIG.USE_LOCKED {true} \
                        CONFIG.USE_RESET {true} \
                        CONFIG.RESET_TYPE {ACTIVE_LOW} \
                        CONFIG.RESET_PORT {resetn} \
                        ] $design_clk_wiz

    connect_bd_net [get_bd_pins $design_clk_wiz/resetn] [get_bd_pins -regexp $mig/((mmcm_locked)|(c0_init_calib_complete))]
    connect_bd_net [get_bd_pins $design_clk_wiz/locked] $design_aresetn

    # connect external design clk
    connect_bd_net [get_bd_pins $design_clk_wiz/design_clk] $design_clk

    connect_bd_net [get_bd_pins $ddr_aclk] [get_bd_pins $design_clk_wiz/clk_in1]

    if {[get_property CONFIG.POLARITY [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk_sync_rst]] == "ACTIVE_HIGH"} {
        set ddr_rst_inverter [tapasco::ip::create_logic_vector "ddr_rst_inverter"]
        set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $ddr_rst_inverter]
        connect_bd_net [get_bd_pins $ddr_rst_inverter/Op1] [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk_sync_rst]
        connect_bd_net [get_bd_pins $ddr_rst_inverter/Res] $ddr_aresetn
    } else {
        connect_bd_net $ddr_aresetn [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk_sync_rst]
    }

    # FIXME belongs into plugin
    # connect cache clk/rst if configured
    if {$cache_en} {
      connect_bd_net $ddr_clk [get_bd_pins $cache/ACLK]
      connect_bd_net $ddr_p_aresetn [get_bd_pins $cache/ARESETN]
    }

  }

  proc create_subsystem_host {} {
    puts "Creating PCIe subsystem ..."

    # create hierarchical ports
    set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_HOST"]
    set m_arch [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_ARCH"]
    set m_intc [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_INTC"]
    set m_tapasco [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_TAPASCO"]
    set m_dma [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DMA"]
    set pcie_aclk [create_bd_pin -type "clk" -dir "O" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "O" "pcie_aresetn"]
    set msix_interface [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:pcie3_cfg_msix_rtl:1.0 "S_MSIX"]

    # create instances of cores: PCIe core, mm_to_lite
    set pcie [create_pcie_core]

    connect_bd_intf_net $msix_interface [get_bd_intf_pins $pcie/pcie_cfg_msix]

    set bridge [create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:PCIeBridgeToLite:1.0 "PCIeBridgeToLite"]
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] [get_bd_pins $bridge/S_AXI_ACLK]
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aresetn] [get_bd_pins $bridge/S_AXI_ARESETN]

    connect_bd_intf_net [get_bd_intf_pins -regexp $pcie/M_AXI(_B)?] \
      [get_bd_intf_pins -of_objects $bridge -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]

    set out_ic [tapasco::ip::create_axi_sc "out_ic" 1 4]
    tapasco::ip::connect_sc_default_clocks $out_ic "host"
    connect_bd_intf_net [get_bd_intf_pins -of_objects $bridge -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Master"] \
      [get_bd_intf_pins -of_objects $out_ic -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]

    set in_ic [tapasco::ip::create_axi_sc "in_ic" 2 1]
    tapasco::ip::connect_sc_default_clocks $in_ic "host"

    connect_bd_intf_net [get_bd_intf_pins S_HOST] [get_bd_intf_pins $in_ic/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins -of_object $in_ic -filter { MODE == Master }] \
      [get_bd_intf_pins -regexp $pcie/S_AXI(_B)?]

    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M00_AXI}] $m_arch
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M01_AXI}] $m_intc
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M02_AXI}] $m_tapasco
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M03_AXI}] $m_dma

    # forward PCIe clock to external ports
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] $pcie_aclk

    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aresetn] $pcie_aresetn
  }

  proc create_subsystem_clocks_and_resets {} {
    # create ports
    set pcie_clk [create_bd_pin -type "clk" -dir "I" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "I" "pcie_aresetn"]
    set ddr_clk [create_bd_pin -type "clk" -dir "I" "ddr_aclk"]
    set ddr_clk_aresetn [create_bd_pin -type "rst" -dir "I" "ddr_aresetn"]
    set design_clk [create_bd_pin -type "clk" -dir "I" "design_aclk"]
    set design_clk_aresetn [create_bd_pin -type "rst" -dir "I" "design_aresetn"]

    # create reset generator
    set host_rst_gen [tapasco::ip::create_rst_gen "host_rst_gen"]
    set design_rst_gen [tapasco::ip::create_rst_gen "design_rst_gen"]
    set mem_rst_gen [tapasco::ip::create_rst_gen "mem_rst_gen"]

    # connect external ports
    connect_bd_net $pcie_clk [get_bd_pins $host_rst_gen/slowest_sync_clk] [tapasco::subsystem::get_port "host" "clk"]
    connect_bd_net $pcie_aresetn [get_bd_pins $host_rst_gen/ext_reset_in]

    connect_bd_net $ddr_clk [get_bd_pins $mem_rst_gen/slowest_sync_clk] [tapasco::subsystem::get_port "mem" "clk"]
    connect_bd_net $ddr_clk_aresetn [get_bd_pins $mem_rst_gen/ext_reset_in]

    connect_bd_net $design_clk [get_bd_pins $design_rst_gen/slowest_sync_clk] [tapasco::subsystem::get_port "design" "clk"]
    connect_bd_net $design_clk_aresetn [get_bd_pins $design_rst_gen/ext_reset_in]

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

  proc get_pe_base_address {} {
    return 0x02000000;
  }
