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
# @file		vc709.tcl
# @brief	VC709 platform implementation.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
# @author	J. A. Hofmann, TU Darmstadt (jah@esa.tu-darmstadt.de)
#
namespace eval platform {
  namespace export create
  namespace export max_masters
  namespace export create_subsystem_clocks_and_resets
  namespace export create_subsystem_host
  namespace export create_subsystem_memory
  namespace export create_subsystem_intc
  namespace export create_subsystem_tapasco

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/vc709/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list 128]
  }

  proc get_address_map {{pe_base ""}} {
    set max32 [expr "1 << 32"]
    set max64 [expr "1 << 64"]
    if {$pe_base == ""} { set pe_base [get_pe_base_address] }
    set peam [::arch::get_address_map $pe_base]
    puts "Computing addresses for masters ..."
    foreach m [::tapasco::get_aximm_interfaces [get_bd_cells -filter "PATH !~ [::tapasco::subsystem::get arch]/*"]] {
      switch -glob [get_property NAME $m] {
        "M_DMA"     { foreach {base stride range} [list 0x00300000 0x10000 0     ] {} }
        "M_INTC"    { foreach {base stride range} [list 0x00500000 0x10000 0     ] {} }
        "M_MSIX"    { foreach {base stride range} [list 0          0       $max64] {} }
        "M_TAPASCO" { foreach {base stride range} [list 0x02800000 0       0     ] {} }
        "M_HOST"    { foreach {base stride range} [list 0          0       $max64] {} }
        "M_ARCH"    { set base "skip" }
        default     { foreach {base stride range} [list 0 0 0]                     {} }
      }
      if {$base != "skip"} { set peam [assign_address $peam $m $base $stride $range] }
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
    set aclk [tapasco::subsystem::get_port "host" "clk"]
    set ic_aresetn [tapasco::subsystem::get_port "host" "rst" "interconnect"]
    set p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set dma_irq_read [create_bd_pin -type "intr" -dir I "dma_irq_read"]
    set dma_irq_write [create_bd_pin -type "intr" -dir I "dma_irq_write"]

    set msix_fail [create_bd_pin -dir "I" "msix_fail"]
    set msix_sent [create_bd_pin -dir "I" "msix_sent"]
    set msix_enable [create_bd_pin -from 3 -to 0 -dir "I" "msix_enable"]
    set msix_mask [create_bd_pin -from 3 -to 0 -dir "I" "msix_mask"]
    set msix_data [create_bd_pin -from 31 -to 0 -dir "O" "msix_data"]
    set msix_addr [create_bd_pin -from 63 -to 0 -dir "O" "msix_addr"]
    set msix_int [create_bd_pin -dir "O" "msix_int"]
    set m_axi [create_bd_intf_pin -mode Master -vlnv [tapasco::ip::get_vlnv "aximm_intf"] "M_MSIX"]

    set num_irqs 132
    set num_irqs_threadpools 128

    set irq_concat_ss [tapasco::ip::create_xlconcat "interrupt_concat" 6]

    # create MSIX interrupt controller
    set msix_intr_ctrl [tapasco::ip::create_msix_intr_ctrl "msix_intr_ctrl"]
    connect_bd_net [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "dout"}] [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "interrupt"}]

    connect_bd_intf_net [get_bd_intf_pins -of_objects $msix_intr_ctrl -filter {NAME == "M_AXI"}] $m_axi
    connect_bd_net [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "cfg_interrupt_msix_address"}] $msix_addr
    connect_bd_net [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "cfg_interrupt_msix_data"}] $msix_data
    connect_bd_net [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "cfg_interrupt_msix_int"}] $msix_int
    connect_bd_net $msix_sent [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "cfg_interrupt_msix_sent"}]
    connect_bd_net $msix_fail [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "cfg_interrupt_msix_fail"}]
    connect_bd_net $msix_enable [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "cfg_interrupt_msix_enable"}]
    connect_bd_net $msix_mask [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "cfg_interrupt_msix_mask"}]

    connect_bd_net $dma_irq_read [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In0"}]
    connect_bd_net $dma_irq_write [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In1"}]
    puts "Unused Interrupts: 2, 3 are tied to 0"
    set irq_unused [tapasco::ip::create_constant "irq_unused" 1 0]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In2"}]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In3"}]

    for {set i 0} {$i < 1} {incr i} {
      set port [create_bd_pin -from 63 -to 0 -dir I -type intr "intr_$i"]
      connect_bd_net $port [get_bd_pin $irq_concat_ss/[format "In%d" [expr "$i + 4"]]]
    }

    # connect internal clocks
    connect_bd_net $aclk [get_bd_pins -of_objects [get_bd_cells -filter {VLNV !~ "*:tapasco:*"}] -filter {TYPE == "clk" && DIR == "I"}]
    # connect internal interconnect resets
    set ic_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV =~ "*:axi_interconnect:*"}] -filter {NAME == "ARESETN"}]
    if {[llength $ic_resets] > 0} { connect_bd_net $ic_aresetn $ic_resets }
    # connect internal peripheral resets
    set p_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV !~ "*:tapasco:*"}] -filter {TYPE == rst && DIR == I && NAME != "ARESETN"}]
    puts "connect_bd_net $p_aresetn $p_resets"
    connect_bd_net $p_aresetn $p_resets

    # connect S_AXI
    connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI"}]
  }

  # Creates the memory subsystem consisting of MIG core for DDR RAM,
  # and a Dual DMA engine which is connected to the MIG and has an
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

    # create instances of cores: MIG core, dual DMA, system cache
    set mig [create_mig_core "mig"]
    set dual_dma [tapasco::ip::create_dualdma "dual_dma"]
    set mig_ic [tapasco::ip::create_axi_ic "mig_ic" 2 1]
    set_property -dict [list \
      CONFIG.S01_HAS_DATA_FIFO {2}
    ] $mig_ic

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
      connect_bd_intf_net [get_bd_intf_pins $cache/M_AXI] [get_bd_intf_pins mig/S_AXI]
    } {
      puts "Platform configured w/o L2 Cache"
      # no cache - connect directly to MIG
      connect_bd_intf_net [get_bd_intf_pins mig_ic/M00_AXI] [get_bd_intf_pins mig/S_AXI]
    }

    # AXI connections:
    # connect dual dma 32bit to mig_ic
    connect_bd_intf_net [get_bd_intf_pins dual_dma/M32_AXI] [get_bd_intf_pins mig_ic/S00_AXI]
    # connect dual DMA 64bit to external port
    connect_bd_intf_net [get_bd_intf_pins dual_dma/M64_AXI] $m_axi_mem
    # connect second mig_ic slave to external port
    connect_bd_intf_net $s_axi_mem [get_bd_intf_pins mig_ic/S01_AXI]
    # connect dual DMA S_AXI to external port
    connect_bd_intf_net $s_axi_ddma [get_bd_intf_pins dual_dma/S_AXI]

    # connect PCIe clock and reset
    connect_bd_net $pcie_aclk [get_bd_pins dual_dma/m64_axi_aclk] [get_bd_pins dual_dma/s_axi_aclk]
    connect_bd_net $pcie_p_aresetn [get_bd_pins dual_dma/m64_axi_aresetn] [get_bd_pins dual_dma/s_axi_aresetn]

    # connect DDR clock and reset
    set ddr_clk [get_bd_pins mig/ui_clk]
    connect_bd_net [tapasco::subsystem::get_port "mem" "clk"] \
      [get_bd_pins mig_ic/ACLK] \
      [get_bd_pins mig_ic/M00_ACLK] \
      [get_bd_pins mig_ic/S00_ACLK] \
      [get_bd_pins dual_dma/m32_axi_aclk]
    connect_bd_net $ddr_ic_aresetn [get_bd_pins mig_ic/ARESETN]
    connect_bd_net $ddr_p_aresetn \
      [get_bd_pins mig_ic/M00_ARESETN] \
      [get_bd_pins mig_ic/S00_ARESETN] \
      [get_bd_pins dual_dma/m32_axi_aresetn] \
      [get_bd_pins mig/aresetn]

    # connect external DDR clk/rst output ports
    connect_bd_net [get_bd_pins mig/ui_clk_sync_rst] $ddr_aresetn $design_aresetn
    connect_bd_net $ddr_clk $ddr_aclk

    # connect internal design clk/rst
    connect_bd_net $design_aclk [get_bd_pins mig_ic/S01_ACLK]
    connect_bd_net $design_p_aresetn [get_bd_pins mig_ic/S01_ARESETN]

    # connect external design clk
    set ext_design_clk [get_bd_pins mig/ui_clk]
    if {[tapasco::get_design_frequency] != [tapasco::get_mem_frequency]} {
      set ext_design_clk [get_bd_pins mig/ui_addn_clk_0]
    }
    connect_bd_net $ext_design_clk $design_clk

    # FIXME belongs into plugin
    # connect cache clk/rst if configured
    if {$cache_en} {
      connect_bd_net $ddr_clk [get_bd_pins $cache/ACLK]
      connect_bd_net $ddr_p_aresetn [get_bd_pins $cache/ARESETN]
    }

    # connect IRQ
     if {[tapasco::is_feature_enabled "BlueDMA"]} {
       connect_bd_net [get_bd_pins dual_dma/IRQ_read] $irq_read
       connect_bd_net [get_bd_pins dual_dma/IRQ_write] $irq_write
     } else {
       connect_bd_net [get_bd_pins dual_dma/IRQ] $irq_read
     }
  }

  proc create_subsystem_host {} {
    puts "Creating PCIe subsystem ..."

    # create hierarchical ports
    set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_HOST"]
    set s_msix [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MSIX"]
    set m_arch [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_ARCH"]
    set m_intc [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_INTC"]
    set m_tapasco [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_TAPASCO"]
    set m_dma [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DMA"]
    set pcie_aclk [create_bd_pin -type "clk" -dir "O" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "O" "pcie_aresetn"]

    set msix_fail [create_bd_pin -dir "O" "msix_fail"]
    set msix_sent [create_bd_pin -dir "O" "msix_sent"]
    set msix_enable [create_bd_pin -from 3 -to 0 -dir "O" "msix_enable"]
    set msix_mask [create_bd_pin -from 3 -to 0 -dir "O" "msix_mask"]
    set msix_data [create_bd_pin -from 31 -to 0 -dir "I" "msix_data"]
    set msix_addr [create_bd_pin -from 63 -to 0 -dir "I" "msix_addr"]
    set msix_int [create_bd_pin -dir "I" "msix_int"]

    # create instances of cores: PCIe core, mm_to_lite
    set pcie [create_pcie_core]
    set mm_to_lite_proto [tapasco::ip::create_proto_conv "mm_to_lite_proto" "AXI4" "AXI4LITE"]
    set mm_to_lite_slice_before [tapasco::ip::create_axi_reg_slice "mm_to_lite_slice_before"]
    set mm_to_lite_slice_mid [tapasco::ip::create_axi_reg_slice "mm_to_lite_slice_mid"]
    set mm_to_lite_slice_after [tapasco::ip::create_axi_reg_slice "mm_to_lite_slice_after"]
    set mm_to_lite_dwidth [tapasco::ip::create_dwidth_conv "mm_to_lite_dwidth" 256]

    # connect PCIe slave to external port
    #connect_bd_intf_net $s_axi [get_bd_intf_pins axi_pcie3_0/S_AXI]
    # connect PCIe master to external port
    connect_bd_intf_net [get_bd_intf_pins axi_pcie3_0/M_AXI] [get_bd_intf_pins mm_to_lite_slice_before/S_AXI]
    # connect mm_to_lite datawidth converter to protocol converter
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_before/M_AXI] [get_bd_intf_pins mm_to_lite_dwidth/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_dwidth/M_AXI] [get_bd_intf_pins mm_to_lite_slice_mid/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_mid/M_AXI] [get_bd_intf_pins mm_to_lite_proto/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_proto/M_AXI] [get_bd_intf_pins mm_to_lite_slice_after/S_AXI]

    # FIXME are the default settings for the IC ok?
    set out_ic [tapasco::ip::create_axi_ic "out_ic" 1 4]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_after/M_AXI] \
      [get_bd_intf_pins -of_objects $out_ic -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]

    set in_ic [tapasco::ip::create_axi_ic "in_ic" 2 1]
    connect_bd_intf_net [get_bd_intf_pins S_HOST] [get_bd_intf_pins $in_ic/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins S_MSIX] [get_bd_intf_pins $in_ic/S01_AXI]
    connect_bd_intf_net [get_bd_intf_pins -of_object $in_ic -filter { MODE == Master }] \
      [get_bd_intf_pins $pcie/S_AXI]

    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M00_AXI}] $m_arch
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M01_AXI}] $m_intc
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M02_AXI}] $m_tapasco
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M03_AXI}] $m_dma

    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] \
      [get_bd_pins $out_ic/ACLK] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ S0* && TYPE == clk}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M01_* && TYPE == clk}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M03_* && TYPE == clk}] \
      [get_bd_pins -of_objects $in_ic  -filter {TYPE == clk}]
    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M00_* && TYPE == clk}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M02_* && TYPE == clk}]

    connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] \
      [get_bd_pins $out_ic/ARESETN] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ S0* && TYPE == rst}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M01_* && TYPE == rst}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M03_* && TYPE == rst}] \
      [get_bd_pins -of_objects $in_ic  -filter {TYPE == rst}]
    connect_bd_net [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M00_* && TYPE == rst}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M02_* && TYPE == rst}]

    set version [lindex [split [get_property VLNV [get_bd_cells axi_pcie3_0]] :] end]
    if {[expr "$version < 3.0"]} {
      # connect axi_ctl_aclk (unused) to axi_aclk
      connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] [get_bd_pins axi_pcie3_0/axi_ctl_aclk]
    }

    # connect msix signals to external ports
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_enable] $msix_enable
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_mask] $msix_mask
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_fail] $msix_fail
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_sent] $msix_sent

    connect_bd_net $msix_addr [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_address]
    connect_bd_net $msix_data [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_data]
    connect_bd_net $msix_int [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_int]

    # forward PCIe clock to external ports
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] $pcie_aclk
    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] \
      [get_bd_pins mm_to_lite_dwidth/s_axi_aclk] \
      [get_bd_pins mm_to_lite_proto/aclk] \
      [get_bd_pins mm_to_lite_slice_before/aclk] \
      [get_bd_pins mm_to_lite_slice_mid/aclk] \
      [get_bd_pins mm_to_lite_slice_after/aclk]

    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aresetn] $pcie_aresetn
    connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] \
      [get_bd_pins mm_to_lite_dwidth/s_axi_aresetn] \
      [get_bd_pins mm_to_lite_proto/aresetn] \
      [get_bd_pins mm_to_lite_slice_before/aresetn] \
      [get_bd_pins mm_to_lite_slice_mid/aresetn] \
      [get_bd_pins mm_to_lite_slice_after/aresetn]
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
      CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perst} \
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
    set refclk_ibuf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 refclk_ibuf ]
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
    puts $constraints_file "set_property LOC IBUFDS_GTE2_X1Y11 \[get_cells {system_i/host/refclk_ibuf/U0/USE_IBUFDS_GTE2.GEN_IBUFDS_GTE2[0].IBUFDS_GTE2_I}\]"
    close $constraints_file
    read_xdc $constraints_fn

    return $axi_pcie3_0
  }

  proc get_pe_base_address {} {
    return 0x02000000
  }

  ##################################################################
  # MIG PRJ FILE TCL PROCs
  ##################################################################

  proc write_mig_file_design_1_mig_7series_0_0 { str_mig_prj_filepath } {
    set freq [tapasco::get_design_frequency]
    set div [format "%1.3f" [expr "800.0 / $freq"]]
    set rf  [format "%3.2f" [expr "800.0 / $div"]]
    puts "  target frequency: $freq, divisor: $div, approx. frequency: $rf"
    if {$freq > 800} {
      puts "ERROR - invalid design frequency $freq!"
      exit 1
    }
    set clock_line "        <MMCMClkOut0>$div</MMCMClkOut0>"

    if {$freq == 200} {
      set clock_en_line {        <UIExtraClocks>0</UIExtraClocks>}
    } {
      set clock_en_line {        <UIExtraClocks>1</UIExtraClocks>}
    }

    set mig_prj_file [open $str_mig_prj_filepath  w+]

    puts $mig_prj_file {<?xml version='1.0' encoding='UTF-8'?>}
    puts $mig_prj_file {<Project NoOfControllers="1" >}
    puts $mig_prj_file {    <ModuleName>design_1_mig_7series_0_0</ModuleName>}
    puts $mig_prj_file {    <dci_inouts_inputs>1</dci_inouts_inputs>}
    puts $mig_prj_file {    <dci_inputs>1</dci_inputs>}
    puts $mig_prj_file {    <Debug_En>OFF</Debug_En>}
    puts $mig_prj_file {    <DataDepth_En>1024</DataDepth_En>}
    puts $mig_prj_file {    <LowPower_En>ON</LowPower_En>}
    puts $mig_prj_file {    <XADC_En>Enabled</XADC_En>}
    puts $mig_prj_file {    <TargetFPGA>xc7vx690t-ffg1761/-2</TargetFPGA>}
    puts $mig_prj_file {    <Version>2.3</Version>}
    puts $mig_prj_file {    <SystemClock>Differential</SystemClock>}
    puts $mig_prj_file {    <ReferenceClock>Use System Clock</ReferenceClock>}
    puts $mig_prj_file {    <SysResetPolarity>ACTIVE HIGH</SysResetPolarity>}
    puts $mig_prj_file {    <BankSelectionFlag>FALSE</BankSelectionFlag>}
    puts $mig_prj_file {    <InternalVref>0</InternalVref>}
    puts $mig_prj_file {    <dci_hr_inouts_inputs>50 Ohms</dci_hr_inouts_inputs>}
    puts $mig_prj_file {    <dci_cascade>1</dci_cascade>}
    puts $mig_prj_file {    <Controller number="0" >}
    puts $mig_prj_file {        <MemoryDevice>DDR3_SDRAM/SODIMMs/MT8KTF51264HZ-1G9</MemoryDevice>}
    puts $mig_prj_file {        <TimePeriod>1250</TimePeriod>}
    puts $mig_prj_file {        <VccAuxIO>2.0V</VccAuxIO>}
    puts $mig_prj_file {        <PHYRatio>4:1</PHYRatio>}
    puts $mig_prj_file {        <InputClkFreq>200</InputClkFreq>}
    puts $mig_prj_file $clock_en_line
    puts $mig_prj_file {        <MMCM_VCO>800</MMCM_VCO>}
    puts $mig_prj_file $clock_line
    puts $mig_prj_file {        <MMCMClkOut1>1</MMCMClkOut1>}
    puts $mig_prj_file {        <MMCMClkOut2>1</MMCMClkOut2>}
    puts $mig_prj_file {        <MMCMClkOut3>1</MMCMClkOut3>}
    puts $mig_prj_file {        <MMCMClkOut4>1</MMCMClkOut4>}
    puts $mig_prj_file {        <DataWidth>64</DataWidth>}
    puts $mig_prj_file {        <DeepMemory>1</DeepMemory>}
    puts $mig_prj_file {        <DataMask>1</DataMask>}
    puts $mig_prj_file {        <ECC>Disabled</ECC>}
    puts $mig_prj_file {        <Ordering>Normal</Ordering>}
    puts $mig_prj_file {        <CustomPart>FALSE</CustomPart>}
    puts $mig_prj_file {        <NewPartName></NewPartName>}
    puts $mig_prj_file {        <RowAddress>16</RowAddress>}
    puts $mig_prj_file {        <ColAddress>10</ColAddress>}
    puts $mig_prj_file {        <BankAddress>3</BankAddress>}
    puts $mig_prj_file {        <MemoryVoltage>1.5V</MemoryVoltage>}
    puts $mig_prj_file {        <C0_MEM_SIZE>4294967296</C0_MEM_SIZE>}
    puts $mig_prj_file {        <UserMemoryAddressMap>BANK_ROW_COLUMN</UserMemoryAddressMap>}
    puts $mig_prj_file {        <PinSelection>}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="A20" SLEW="" name="ddr3_addr[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="B21" SLEW="" name="ddr3_addr[10]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="B17" SLEW="" name="ddr3_addr[11]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="A15" SLEW="" name="ddr3_addr[12]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="A21" SLEW="" name="ddr3_addr[13]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="F17" SLEW="" name="ddr3_addr[14]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="E17" SLEW="" name="ddr3_addr[15]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="B19" SLEW="" name="ddr3_addr[1]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="C20" SLEW="" name="ddr3_addr[2]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="A19" SLEW="" name="ddr3_addr[3]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="A17" SLEW="" name="ddr3_addr[4]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="A16" SLEW="" name="ddr3_addr[5]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="D20" SLEW="" name="ddr3_addr[6]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="C18" SLEW="" name="ddr3_addr[7]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="D17" SLEW="" name="ddr3_addr[8]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="C19" SLEW="" name="ddr3_addr[9]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="D21" SLEW="" name="ddr3_ba[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="C21" SLEW="" name="ddr3_ba[1]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="D18" SLEW="" name="ddr3_ba[2]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="K17" SLEW="" name="ddr3_cas_n" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15" PADName="E18" SLEW="" name="ddr3_ck_n[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15" PADName="E19" SLEW="" name="ddr3_ck_p[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="K19" SLEW="" name="ddr3_cke[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="J17" SLEW="" name="ddr3_cs_n[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="M13" SLEW="" name="ddr3_dm[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="K15" SLEW="" name="ddr3_dm[1]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="F12" SLEW="" name="ddr3_dm[2]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="A14" SLEW="" name="ddr3_dm[3]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="C23" SLEW="" name="ddr3_dm[4]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="D25" SLEW="" name="ddr3_dm[5]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="C31" SLEW="" name="ddr3_dm[6]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="F31" SLEW="" name="ddr3_dm[7]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="N14" SLEW="" name="ddr3_dq[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="H13" SLEW="" name="ddr3_dq[10]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="J13" SLEW="" name="ddr3_dq[11]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="L16" SLEW="" name="ddr3_dq[12]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="L15" SLEW="" name="ddr3_dq[13]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="H14" SLEW="" name="ddr3_dq[14]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="J15" SLEW="" name="ddr3_dq[15]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E15" SLEW="" name="ddr3_dq[16]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E13" SLEW="" name="ddr3_dq[17]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="F15" SLEW="" name="ddr3_dq[18]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E14" SLEW="" name="ddr3_dq[19]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="N13" SLEW="" name="ddr3_dq[1]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="G13" SLEW="" name="ddr3_dq[20]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="G12" SLEW="" name="ddr3_dq[21]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="F14" SLEW="" name="ddr3_dq[22]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="G14" SLEW="" name="ddr3_dq[23]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="B14" SLEW="" name="ddr3_dq[24]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="C13" SLEW="" name="ddr3_dq[25]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="B16" SLEW="" name="ddr3_dq[26]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D15" SLEW="" name="ddr3_dq[27]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D13" SLEW="" name="ddr3_dq[28]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E12" SLEW="" name="ddr3_dq[29]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="L14" SLEW="" name="ddr3_dq[2]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="C16" SLEW="" name="ddr3_dq[30]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D16" SLEW="" name="ddr3_dq[31]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="A24" SLEW="" name="ddr3_dq[32]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="B23" SLEW="" name="ddr3_dq[33]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="B27" SLEW="" name="ddr3_dq[34]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="B26" SLEW="" name="ddr3_dq[35]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="A22" SLEW="" name="ddr3_dq[36]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="B22" SLEW="" name="ddr3_dq[37]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="A25" SLEW="" name="ddr3_dq[38]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="C24" SLEW="" name="ddr3_dq[39]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="M14" SLEW="" name="ddr3_dq[3]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E24" SLEW="" name="ddr3_dq[40]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D23" SLEW="" name="ddr3_dq[41]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D26" SLEW="" name="ddr3_dq[42]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="C25" SLEW="" name="ddr3_dq[43]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E23" SLEW="" name="ddr3_dq[44]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D22" SLEW="" name="ddr3_dq[45]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="F22" SLEW="" name="ddr3_dq[46]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E22" SLEW="" name="ddr3_dq[47]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="A30" SLEW="" name="ddr3_dq[48]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D27" SLEW="" name="ddr3_dq[49]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="M12" SLEW="" name="ddr3_dq[4]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="A29" SLEW="" name="ddr3_dq[50]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="C28" SLEW="" name="ddr3_dq[51]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D28" SLEW="" name="ddr3_dq[52]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="B31" SLEW="" name="ddr3_dq[53]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="A31" SLEW="" name="ddr3_dq[54]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="A32" SLEW="" name="ddr3_dq[55]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E30" SLEW="" name="ddr3_dq[56]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="F29" SLEW="" name="ddr3_dq[57]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="F30" SLEW="" name="ddr3_dq[58]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="F27" SLEW="" name="ddr3_dq[59]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="N15" SLEW="" name="ddr3_dq[5]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="C30" SLEW="" name="ddr3_dq[60]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="E29" SLEW="" name="ddr3_dq[61]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="F26" SLEW="" name="ddr3_dq[62]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="D30" SLEW="" name="ddr3_dq[63]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="M11" SLEW="" name="ddr3_dq[6]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="L12" SLEW="" name="ddr3_dq[7]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="K14" SLEW="" name="ddr3_dq[8]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15_T_DCI" PADName="K13" SLEW="" name="ddr3_dq[9]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="M16" SLEW="" name="ddr3_dqs_n[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="J12" SLEW="" name="ddr3_dqs_n[1]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="G16" SLEW="" name="ddr3_dqs_n[2]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="C14" SLEW="" name="ddr3_dqs_n[3]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="A27" SLEW="" name="ddr3_dqs_n[4]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="E25" SLEW="" name="ddr3_dqs_n[5]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="B29" SLEW="" name="ddr3_dqs_n[6]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="E28" SLEW="" name="ddr3_dqs_n[7]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="N16" SLEW="" name="ddr3_dqs_p[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="K12" SLEW="" name="ddr3_dqs_p[1]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="H16" SLEW="" name="ddr3_dqs_p[2]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="C15" SLEW="" name="ddr3_dqs_p[3]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="A26" SLEW="" name="ddr3_dqs_p[4]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="F25" SLEW="" name="ddr3_dqs_p[5]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="B28" SLEW="" name="ddr3_dqs_p[6]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="E27" SLEW="" name="ddr3_dqs_p[7]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="H20" SLEW="" name="ddr3_odt[0]" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="E20" SLEW="" name="ddr3_ras_n" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="LVCMOS15" PADName="P18" SLEW="" name="ddr3_reset_n" IN_TERM="" />}
    puts $mig_prj_file {            <Pin VCCAUX_IO="HIGH" IOSTANDARD="SSTL15" PADName="F20" SLEW="" name="ddr3_we_n" IN_TERM="" />}
    puts $mig_prj_file {        </PinSelection>}
    puts $mig_prj_file {        <System_Clock>}
    puts $mig_prj_file {            <Pin PADName="H19/G18(CC_P/N)" Bank="38" name="sys_clk_p/n" />}
    puts $mig_prj_file {        </System_Clock>}
    puts $mig_prj_file {        <System_Control>}
    puts $mig_prj_file {            <Pin PADName="No connect" Bank="Select Bank" name="sys_rst" />}
    puts $mig_prj_file {            <Pin PADName="AM39" Bank="15" name="init_calib_complete" />}
    puts $mig_prj_file {            <Pin PADName="No connect" Bank="Select Bank" name="tg_compare_error" />}
    puts $mig_prj_file {        </System_Control>}
    puts $mig_prj_file {        <TimingParameters>}
    puts $mig_prj_file {            <Parameters twtr="7.5" trrd="5" trefi="7.8" tfaw="27" trtp="7.5" tcke="5" trfc="260" trp="13.91" tras="34" trcd="13.91" />}
    puts $mig_prj_file {        </TimingParameters>}
    puts $mig_prj_file {        <mrBurstLength name="Burst Length" >8 - Fixed</mrBurstLength>}
    puts $mig_prj_file {        <mrBurstType name="Read Burst Type and Length" >Sequential</mrBurstType>}
    puts $mig_prj_file {        <mrCasLatency name="CAS Latency" >11</mrCasLatency>}
    puts $mig_prj_file {        <mrMode name="Mode" >Normal</mrMode>}
    puts $mig_prj_file {        <mrDllReset name="DLL Reset" >No</mrDllReset>}
    puts $mig_prj_file {        <mrPdMode name="DLL control for precharge PD" >Slow Exit</mrPdMode>}
    puts $mig_prj_file {        <emrDllEnable name="DLL Enable" >Enable</emrDllEnable>}
    puts $mig_prj_file {        <emrOutputDriveStrength name="Output Driver Impedance Control" >RZQ/7</emrOutputDriveStrength>}
    puts $mig_prj_file {        <emrMirrorSelection name="Address Mirroring" >Disable</emrMirrorSelection>}
    puts $mig_prj_file {        <emrCSSelection name="Controller Chip Select Pin" >Enable</emrCSSelection>}
    puts $mig_prj_file {        <emrRTT name="RTT (nominal) - On Die Termination (ODT)" >RZQ/6</emrRTT>}
    puts $mig_prj_file {        <emrPosted name="Additive Latency (AL)" >0</emrPosted>}
    puts $mig_prj_file {        <emrOCD name="Write Leveling Enable" >Disabled</emrOCD>}
    puts $mig_prj_file {        <emrDQS name="TDQS enable" >Enabled</emrDQS>}
    puts $mig_prj_file {        <emrRDQS name="Qoff" >Output Buffer Enabled</emrRDQS>}
    puts $mig_prj_file {        <mr2PartialArraySelfRefresh name="Partial-Array Self Refresh" >Full Array</mr2PartialArraySelfRefresh>}
    puts $mig_prj_file {        <mr2CasWriteLatency name="CAS write latency" >8</mr2CasWriteLatency>}
    puts $mig_prj_file {        <mr2AutoSelfRefresh name="Auto Self Refresh" >Enabled</mr2AutoSelfRefresh>}
    puts $mig_prj_file {        <mr2SelfRefreshTempRange name="High Temparature Self Refresh Rate" >Normal</mr2SelfRefreshTempRange>}
    puts $mig_prj_file {        <mr2RTTWR name="RTT_WR - Dynamic On Die Termination (ODT)" >Dynamic ODT off</mr2RTTWR>}
    puts $mig_prj_file {        <PortInterface>AXI</PortInterface>}
    puts $mig_prj_file {        <AXIParameters>}
    puts $mig_prj_file {            <C0_C_RD_WR_ARB_ALGORITHM>RD_PRI_REG</C0_C_RD_WR_ARB_ALGORITHM>}
    puts $mig_prj_file {            <C0_S_AXI_ADDR_WIDTH>32</C0_S_AXI_ADDR_WIDTH>}
    puts $mig_prj_file {            <C0_S_AXI_DATA_WIDTH>512</C0_S_AXI_DATA_WIDTH>}
    puts $mig_prj_file {            <C0_S_AXI_ID_WIDTH>1</C0_S_AXI_ID_WIDTH>}
    puts $mig_prj_file {            <C0_S_AXI_SUPPORTS_NARROW_BURST>0</C0_S_AXI_SUPPORTS_NARROW_BURST>}
    puts $mig_prj_file {        </AXIParameters>}
    puts $mig_prj_file {    </Controller>}
    puts $mig_prj_file {</Project>}

    close $mig_prj_file
  }
  # End of write_mig_file_design_1_mig_7series_0_0()

}
