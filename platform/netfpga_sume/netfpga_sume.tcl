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
  namespace export create
  namespace export max_masters

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/netfpga_sume/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list 128]
  }

  # Create interrupt controller subsystem:
  # Consists of AXI_INTC IP cores (as many as required), which are connected by an internal
  # AXI Interconnect (S_AXI port), as well as an PCIe interrupt controller IP which can be
  # connected to the PCIe bridge (required ports external).
  # @param irqs List of the interrupts from the threadpool.
  proc platform_create_subsystem_interrupts {irqs} {
    puts "Connecting [llength $irqs] interrupts .."

    # create hierarchical group
    set group [create_bd_cell -type hier "InterruptControl"]
    set instance [current_bd_instance]
    current_bd_instance $group

    # create hierarchical ports
    set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI"]
    set aclk [create_bd_pin -type "clk" -dir I "aclk"]
    set ic_aresetn [create_bd_pin -type "rst" -dir I "interconnect_aresetn"]
    set p_aresetn [create_bd_pin -type "rst" -dir I "peripheral_aresetn"]
    set dma_irq_read [create_bd_pin -type "intr" -dir I "dma_irq_read"]
    set dma_irq_write [create_bd_pin -type "intr" -dir I "dma_irq_write"]

    set msix_fail [create_bd_pin -dir "I" "msix_fail"]
    set msix_sent [create_bd_pin -dir "I" "msix_sent"]
    set msix_enable [create_bd_pin -from 3 -to 0 -dir "I" "msix_enable"]
    set msix_mask [create_bd_pin -from 3 -to 0 -dir "I" "msix_mask"]
    set msix_data [create_bd_pin -from 31 -to 0 -dir "O" "msix_data"]
    set msix_addr [create_bd_pin -from 63 -to 0 -dir "O" "msix_addr"]
    set msix_int [create_bd_pin -dir "O" "msix_int"]
    set m_axi [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_AXI"]

    set num_irqs 132
    set num_irqs_threadpools 128

    set irq_concat_ss [tapasco::createConcat "interrupt_concat" 8]

    set irq_unused [tapasco::createConstant "irq_unused" 1 0]

    # create MSIX interrupt controller
    set msix_intr_ctrl [tapasco::createMSIXIntrCtrl "msix_intr_ctrl"]
    connect_bd_net [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "dout"}] [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "interrupt"}]


    set curr_pcie_line 4
    # connect interrupts to interrupt controller
    foreach irq $irqs {
      connect_bd_net -boundary_type upper $irq [get_bd_pins -of $irq_concat_ss -filter "NAME == [format "In%d" $curr_pcie_line]"]
      incr curr_pcie_line 1
    }

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
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In2"}]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In3"}]

    # connect internal clocks
    connect_bd_net -net intc_clock_net $aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I"}]
    # connect internal interconnect resets
    set ic_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV =~ "*:axi_interconnect:*"}] -filter {NAME == "ARESETN"}]
    connect_bd_net -net intc_ic_reset_net $ic_aresetn $ic_resets
    # connect internal peripheral resets
    set p_resets [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN"}]
    connect_bd_net -net intc_p_reset_net $p_aresetn $p_resets

    # connect S_AXI
    connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI"}]

    current_bd_instance $instance
    return $group
  }

  # Creates the memory subsystem consisting of MIG core for DDR RAM,
  # and a Dual DMA engine which is connected to the MIG and has an
  # external 64bit M_AXI channel toward PCIe.
  proc platform_create_subsystem_memory {} {
    puts "Creating memory subsystem ..."

    # create hierarchical group
    set group [create_bd_cell -type hier "Memory"]
    set instance [current_bd_instance]
    current_bd_instance $group

    # create hierarchical interface ports
    set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "s_axi_mem"]
    set m_axi_mem [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "m_axi_mem64"]
    set s_axi_ddma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "s_axi_ddma"]

    # create hierarchical ports: clocks
    set sys_clk_external [create_bd_pin -type "clk" -dir "I" "sys_clk"]
    set sys_reset_n_external [create_bd_pin -type "rst" -dir "I" "sys_rst"]

    set pcie_aclk [create_bd_pin -type "clk" -dir "I" "pcie_aclk"]
    set ddr_aclk [create_bd_pin -type "clk" -dir "O" "ddr_aclk"]
    set design_aclk [create_bd_pin -type "clk" -dir "I" "design_aclk"]
    set design_clk [create_bd_pin -type "clk" -dir "O" "design_clk"]

    # create hierarchical ports: resets
    set pcie_p_aresetn [create_bd_pin -type "rst" -dir "I" "pcie_peripheral_aresetn"]
    set ddr_ic_aresetn [create_bd_pin -type "rst" -dir "I" "ddr_interconnect_aresetn"]
    set ddr_p_aresetn [create_bd_pin -type "rst" -dir "I" "ddr_peripheral_aresetn"]
    set design_p_aresetn [create_bd_pin -type "rst" -dir "I" "design_peripheral_aresetn"]

    set ddr_aresetn [create_bd_pin -type "rst" -dir "O" "ddr_aresetn"]
    set irq_read [create_bd_pin -type "intr" -dir "O" "dma_irq_read"]
    set irq_write [create_bd_pin -type "intr" -dir "O" "dma_irq_write"]

    # create instances of cores: MIG core, dual DMA, system cache
    puts "SUME CURRENTLY HAS NO MIG"
    set dual_dma [tapasco::createDualDMA "dual_dma"]
    set mig_ic [tapasco::createInterconnect "mig_ic" 2 1]
    set_property -dict [list \
      CONFIG.S01_HAS_DATA_FIFO {2}
    ] $mig_ic

    set cache_en [tapasco::is_feature_enabled "Cache"]
    if {$cache_en} {
      puts "Platform configured w/L2 Cache, implementing ..."
      set cache [tapasco::createSystemCache "cache_l2" 1 \
          [dict get [tapasco::get_feature "Cache"] "size"] \
          [dict get [tapasco::get_feature "Cache"] "associativity"]]

      # connect mig_ic master to cache_l2
      connect_bd_intf_net [get_bd_intf_pins mig_ic/M00_AXI] [get_bd_intf_pins $cache/S0_AXI_GEN]
      # connect cache_l2 to MIG
    } {
      puts "Platform configured w/o L2 Cache"
      # no cache - connect directly to MIG
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
    set ddr_clk [get_bd_pins $sys_clk_external]
    connect_bd_net -net ddr_clk_net $ddr_clk \
      [get_bd_pins mig_ic/ACLK] \
      [get_bd_pins mig_ic/M00_ACLK] \
      [get_bd_pins mig_ic/S00_ACLK] \
      [get_bd_pins dual_dma/m32_axi_aclk]
    connect_bd_net -net ddr_ic_rst_net $ddr_ic_aresetn [get_bd_pins mig_ic/ARESETN]
    connect_bd_net -net ddr_p_rst_net $ddr_p_aresetn \
      [get_bd_pins mig_ic/M00_ARESETN] \
      [get_bd_pins mig_ic/S00_ARESETN] \
      [get_bd_pins dual_dma/m32_axi_aresetn]

    # connect external DDR clk/rst output ports
    connect_bd_net $sys_reset_n_external $ddr_aresetn
    connect_bd_net $sys_clk_external $ddr_aclk

    # connect internal design clk/rst
    connect_bd_net -net design_clk_net $design_aclk [get_bd_pins mig_ic/S01_ACLK]
    connect_bd_net -net design_rst_net $design_p_aresetn [get_bd_pins mig_ic/S01_ARESETN]

    # connect external design clk
    set ext_design_clk $sys_clk_external
    if {[tapasco::get_design_frequency] != [tapasco::get_mem_frequency]} {
      puts "TODO"
    }
    connect_bd_net $ext_design_clk $design_clk

    # connect cache clk/rst if configured
    if {$cache_en} {
      connect_bd_net -net ddr_clk_net $ddr_clk [get_bd_pins $cache/ACLK]
      connect_bd_net -net ddr_p_rst_net $ddr_p_aresetn [get_bd_pins $cache/ARESETN]
    }

    # connect IRQ
    if {[tapasco::is_feature_enabled "BlueDMA"]} {
      connect_bd_net [get_bd_pins dual_dma/IRQ_read] $irq_read
      connect_bd_net [get_bd_pins dual_dma/IRQ_write] $irq_write
    } else {
      connect_bd_net [get_bd_pins dual_dma/IRQ] $irq_read
      connect_bd_net [get_bd_pins dual_dma/IRQ] $irq_write
    }

    current_bd_instance $instance
    return $group
  }

  proc platform_create_subsystem_pcie {} {
    puts "Creating PCIe subsystem ..."

    # create hierarchical group
    set group [create_bd_cell -type hier "PCIe"]
    set instance [current_bd_instance]
    current_bd_instance $group

    # create hierarchical ports
    set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "s_axi"]
    set m_axi [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "m_axi"]
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
    set mm_to_lite_proto [tapasco::createProtocolConverter "mm_to_lite_proto" "AXI4" "AXI4LITE"]
    set mm_to_lite_slice_before [tapasco::createRegisterSlice "mm_to_lite_slice_before"]
    set mm_to_lite_slice_mid [tapasco::createRegisterSlice "mm_to_lite_slice_mid"]
    set mm_to_lite_slice_after [tapasco::createRegisterSlice "mm_to_lite_slice_after"]
    set mm_to_lite_dwidth [tapasco::createDWidthConverter "mm_to_lite_dwidth" 256 64]

    # connect PCIe slave to external port
    connect_bd_intf_net $s_axi [get_bd_intf_pins axi_pcie3_0/S_AXI]
    # connect PCIe master to external port
    connect_bd_intf_net [get_bd_intf_pins axi_pcie3_0/M_AXI] [get_bd_intf_pins mm_to_lite_slice_before/S_AXI]
    # connect mm_to_lite datawidth converter to protocol converter
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_before/M_AXI] [get_bd_intf_pins mm_to_lite_dwidth/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_dwidth/M_AXI] [get_bd_intf_pins mm_to_lite_slice_mid/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_mid/M_AXI] [get_bd_intf_pins mm_to_lite_proto/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_proto/M_AXI] [get_bd_intf_pins mm_to_lite_slice_after/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_after/M_AXI] $m_axi

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
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] $pcie_aclk [get_bd_pins mm_to_lite_dwidth/s_axi_aclk] [get_bd_pins mm_to_lite_proto/aclk] [get_bd_pins mm_to_lite_slice_before/aclk] [get_bd_pins mm_to_lite_slice_mid/aclk] [get_bd_pins mm_to_lite_slice_after/aclk]
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aresetn] $pcie_aresetn [get_bd_pins mm_to_lite_dwidth/s_axi_aresetn] [get_bd_pins mm_to_lite_proto/aresetn] [get_bd_pins mm_to_lite_slice_before/aresetn] [get_bd_pins mm_to_lite_slice_mid/aresetn] [get_bd_pins mm_to_lite_slice_after/aresetn]

    current_bd_instance $instance
    return $group
  }

  proc platform_create_subsystem_reset {} {
    puts "Creating Reset subsystem ..."

    # create hierarchical group
    set group [create_bd_cell -type hier "Resets"]
    set instance [current_bd_instance]
    current_bd_instance $group

    # create ports
    set pcie_clk [create_bd_pin -type "clk" -dir "I" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "I" "pcie_aresetn"]
    set pcie_interconnect_reset [create_bd_pin -type "rst" -dir "O" "pcie_interconnect_aresetn"]
    set pcie_peripheral_reset [create_bd_pin -type "rst" -dir "O" "pcie_peripheral_aresetn"]
    set ddr_clk [create_bd_pin -type "clk" -dir "I" "ddr_aclk"]
    set ddr_clk_aresetn [create_bd_pin -type "rst" -dir "I" "ddr_clk_aresetn"]
    set ddr_clk_interconnect_reset [create_bd_pin -type "rst" -dir "O" "ddr_clk_interconnect_aresetn"]
    set ddr_clk_peripheral_reset [create_bd_pin -type "rst" -dir "O" "ddr_clk_peripheral_aresetn"]
    set design_clk [create_bd_pin -type "clk" -dir "I" "design_aclk"]
    set design_clk_aresetn [create_bd_pin -type "rst" -dir "I" "design_clk_aresetn"]
    set design_clk_interconnect_reset [create_bd_pin -type "rst" -dir "O" "design_clk_interconnect_aresetn"]
    set design_clk_peripheral_reset [create_bd_pin -type "rst" -dir "O" "design_clk_peripheral_aresetn"]

    # create reset generator
    set pcie_rst_gen [tapasco::createResetGen "pcie_rst_gen"]
    set ddr_clk_rst_gen [tapasco::createResetGen "ddr_clk_rst_gen"]
    set design_clk_rst_gen [tapasco::createResetGen "design_clk_rst_gen"]

    # connect external ports
    connect_bd_net $pcie_clk [get_bd_pins pcie_rst_gen/slowest_sync_clk]
    connect_bd_net $pcie_aresetn [get_bd_pins pcie_rst_gen/ext_reset_in]
    connect_bd_net [get_bd_pins pcie_rst_gen/interconnect_aresetn] $pcie_interconnect_reset
    connect_bd_net [get_bd_pins pcie_rst_gen/peripheral_aresetn] $pcie_peripheral_reset

    connect_bd_net $ddr_clk [get_bd_pins ddr_clk_rst_gen/slowest_sync_clk]
    connect_bd_net $ddr_clk_aresetn [get_bd_pins ddr_clk_rst_gen/ext_reset_in]
    connect_bd_net [get_bd_pins ddr_clk_rst_gen/interconnect_aresetn] $ddr_clk_interconnect_reset
    connect_bd_net [get_bd_pins ddr_clk_rst_gen/peripheral_aresetn] $ddr_clk_peripheral_reset

    connect_bd_net $design_clk [get_bd_pins design_clk_rst_gen/slowest_sync_clk]
    connect_bd_net $design_clk_aresetn [get_bd_pins design_clk_rst_gen/ext_reset_in]
    connect_bd_net [get_bd_pins design_clk_rst_gen/interconnect_aresetn] $design_clk_interconnect_reset
    connect_bd_net [get_bd_pins design_clk_rst_gen/peripheral_aresetn] $design_clk_peripheral_reset

    current_bd_instance $instance
    return $group
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
    set axi_pcie3_0 [tapasco::createPCIeBridge "axi_pcie3_0"]
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

    return $axi_pcie3_0
  }

  proc platform_create_dma_engine {{name "dma_engine"}} {
    puts "Creating DMA engine submodule ..."
    set inst [current_bd_instance]
    set engine [create_bd_cell -type hier dma_engine]
    current_bd_instance $engine
    set dual_dma_0 [tapasco::createDualDMA dual_dma_0]
    current_bd_instance $inst
  }

  proc platform_address_map_set {{tapasco_base 0x0}} {
    # connect AXI slaves
    set master_addr_space [get_bd_addr_spaces "/PCIe/axi_pcie3_0/M_AXI"]
    # connect DMA controllers
    set dmas [lsort [get_bd_addr_segs -of_objects [get_bd_cells "/Memory/dual_dma*"]]]
    set offset [expr "$tapasco_base + 0x00300000"]
    for {set i 0} {$i < [llength $dmas]} {incr i; incr offset 0x10000} {
      create_bd_addr_seg -range 64K -offset $offset $master_addr_space [lindex $dmas $i] "DMA_SEG$i"
    }
    # connect interrupt controllers
    set intcs [lsort [get_bd_addr_segs -of_objects [get_bd_cells /InterruptControl/axi_intc_0*]]]
    set offset [expr "$tapasco_base + 0x00400000"]
    for {set i 0} {$i < [llength $intcs]} {incr i; incr offset 0x10000} {
      create_bd_addr_seg -range 64K -offset $offset $master_addr_space [lindex $intcs $i] "INTC_SEG$i"
    }
    set msix [get_bd_addr_segs -of_objects [get_bd_cells /InterruptControl/msix_intr_ctrl]]
    set offset [expr "$tapasco_base + 0x00500000"]
    create_bd_addr_seg -range 64K -offset $offset $master_addr_space $msix "MSIX_SEG"

    # connect TPC status core
    set status_segs [get_bd_addr_segs -of_objects [get_bd_cells "tapasco_status"]]
    set offset [expr "$tapasco_base + 0x02800000"]
    set i 0
    foreach s $status_segs {
      create_bd_addr_seg -range 4K -offset $offset $master_addr_space $s "STATUS_SEG$i"
      incr i
      incr offset 0x1000
    }

    # connect user IP
    set usrs [lsort [get_bd_addr_segs "/uArch/*"]]
    set offset [expr "$tapasco_base + 0x02000000"]
    for {set i 0} {$i < [llength $usrs]} {incr i; incr offset 0x10000} {
      create_bd_addr_seg -range 64K -offset $offset $master_addr_space [lindex $usrs $i] "USR_SEG$i"
    }

    # connect AXI masters
    foreach dma [lsort [get_bd_cells "/Memory/dual_dma*"]] {
      # connect DMA masters
      set ms [get_bd_addr_spaces $dma/M64_AXI]
      set ts [get_bd_addr_segs /PCIe/axi_pcie3_0/S_AXI/BAR0]
      create_bd_addr_seg -range 16E -offset 0 $ms $ts "SEG_$ms"
    }

    set int_ms [get_bd_addr_spaces /InterruptControl/msix_intr_ctrl/M_AXI]
    set ts [get_bd_addr_segs /PCIe/axi_pcie3_0/S_AXI/BAR0]
    create_bd_addr_seg -range 16E -offset 0 $int_ms $ts "SEG_intr"

  }

  proc platform_address_map {} {
    platform_address_map_set

    # call plugins
    tapasco::call_plugins "post-address-map"
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

    puts $constraints_file "create_clock -add -name pcie_clk_pin -period 10.000 -waveform {0 5.000} \[get_ports {IBUF_DS_P}\];"
    puts $constraints_file "#PCIe Transceivers"
    puts $constraints_file "set_property -dict { PACKAGE_PIN Y4 } \[get_ports { pcie_7x_mgt_txp[0] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN Y3 } \[get_ports { pcie_7x_mgt_txn[0] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN W2 } \[get_ports { pcie_7x_mgt_rxp[0] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN W1 } \[get_ports { pcie_7x_mgt_rxn[0] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AA6 } \[get_ports { pcie_7x_mgt_txp[1] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AA5 } \[get_ports { pcie_7x_mgt_txn[1] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AA2 } \[get_ports { pcie_7x_mgt_rxp[1] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AA1 } \[get_ports { pcie_7x_mgt_rxn[1] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AB4 } \[get_ports { pcie_7x_mgt_txp[2] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AB3 } \[get_ports { pcie_7x_mgt_txn[2] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AC2 } \[get_ports { pcie_7x_mgt_rxp[2] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AC1 } \[get_ports { pcie_7x_mgt_rxn[2] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AC6 } \[get_ports { pcie_7x_mgt_txp[3] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AC5 } \[get_ports { pcie_7x_mgt_txn[3] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AE2 } \[get_ports { pcie_7x_mgt_rxp[3] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AE1 } \[get_ports { pcie_7x_mgt_rxn[3] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AD4 } \[get_ports { pcie_7x_mgt_txp[4] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AD3 } \[get_ports { pcie_7x_mgt_txn[4] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AG2 } \[get_ports { pcie_7x_mgt_rxp[4] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AG1 } \[get_ports { pcie_7x_mgt_rxn[4] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AE6 } \[get_ports { pcie_7x_mgt_txp[5] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AE5 } \[get_ports { pcie_7x_mgt_txn[5] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AH4 } \[get_ports { pcie_7x_mgt_rxp[5] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AH3 } \[get_ports { pcie_7x_mgt_rxn[5] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AF4 } \[get_ports { pcie_7x_mgt_txp[6] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AF3 } \[get_ports { pcie_7x_mgt_txn[6] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AJ2 } \[get_ports { pcie_7x_mgt_rxp[6] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AJ1 } \[get_ports { pcie_7x_mgt_rxn[6] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AG6 } \[get_ports { pcie_7x_mgt_txp[7] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AG5 } \[get_ports { pcie_7x_mgt_txn[7] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AK4 } \[get_ports { pcie_7x_mgt_rxp[7] }\];"
    puts $constraints_file "set_property -dict { PACKAGE_PIN AK3 } \[get_ports { pcie_7x_mgt_rxn[7] }\];"

    close $constraints_file
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
  }

  # Platform API: Entry point for Platform instantiation.
  proc create {} {
    # create interrupt subsystem
    set ss_int [platform_create_subsystem_interrupts [arch::get_irqs]]

    # create memory subsystem
    set ss_mem [platform_create_subsystem_memory]

    # create PCIe subsystem
    set ss_pcie [platform_create_subsystem_pcie]

    # create Reset subsystem
    set ss_reset [platform_create_subsystem_reset]

    # create AXI infrastructure
    set axi_ic_to_host [tapasco::createInterconnect "axi_ic_to_host" 2 1]

    set axi_ic_from_host [tapasco::createInterconnect "axi_ic_from_host" 1 4]

    set axi_ic_to_mem [list]
    if {[llength [arch::get_masters]] > 0} {
      set axi_ic_to_mem [tapasco::createInterconnect "axi_ic_to_mem" [llength [arch::get_masters]] 1]
      connect_bd_intf_net [get_bd_intf_pins $axi_ic_to_mem/M00_AXI] [get_bd_intf_pins /Memory/s_axi_mem]
    }

    set s_n 0
    foreach m [arch::get_masters] {
      connect_bd_intf_net $m [get_bd_intf_pins [format "$axi_ic_to_mem/S%02d_AXI" $s_n]]
      incr s_n
    }

    set sys_clk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk]

    set sys_clk_ibuf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 sys_clk_ibuf ]

    connect_bd_intf_net [get_bd_intf_pins $sys_clk_ibuf/CLK_IN_D] [get_bd_intf_ports sys_clk]

    save_bd_design

    connect_bd_net [get_bd_pins $ss_mem/sys_clk] [get_bd_pins $sys_clk_ibuf/IBUF_OUT]

    connect_bd_net [get_bd_ports pcie_perst] [get_bd_pins $ss_mem/sys_rst]

    # always create TPC status core
    set tapasco_status [tapasco::createTapascoStatus "tapasco_status"]
    puts "Resetting Intc count to 1"
    set_property -dict [list CONFIG.C_INTC_COUNT 1] $tapasco_status
    connect_bd_intf_net [get_bd_intf_pins $axi_ic_from_host/M03_AXI] [get_bd_intf_pins $tapasco_status/S00_AXI]

    # connect PCIe <-> InterruptControl
    connect_bd_net [get_bd_pins $ss_pcie/msix_fail] [get_bd_pins $ss_int/msix_fail]
    connect_bd_net [get_bd_pins $ss_pcie/msix_sent] [get_bd_pins $ss_int/msix_sent]
    connect_bd_net [get_bd_pins $ss_pcie/msix_mask] [get_bd_pins $ss_int/msix_mask]
    connect_bd_net [get_bd_pins $ss_pcie/msix_enable] [get_bd_pins $ss_int/msix_enable]
    connect_bd_net [get_bd_pins $ss_int/msix_data] [get_bd_pins $ss_pcie/msix_data]
    connect_bd_net [get_bd_pins $ss_int/msix_addr] [get_bd_pins $ss_pcie/msix_addr]
    connect_bd_net [get_bd_pins $ss_int/msix_int] [get_bd_pins $ss_pcie/msix_int]

    # connect Memory <-> InterruptControl
    connect_bd_net [get_bd_pins $ss_mem/dma_irq_read] [get_bd_pins $ss_int/dma_irq_read]
    connect_bd_net [get_bd_pins $ss_mem/dma_irq_write] [get_bd_pins $ss_int/dma_irq_write]

    # connect clocks
    set pcie_aclk [get_bd_pins $ss_pcie/pcie_aclk]
    set ddr_clk [get_bd_pins $ss_mem/ddr_aclk]
    set design_clk [get_bd_pins $ss_mem/design_aclk]

    connect_bd_net -net pcie_aclk_net $pcie_aclk \
      [get_bd_pins $ss_mem/pcie_aclk] \
      [get_bd_pins $ss_reset/pcie_aclk] \
      [get_bd_pins -of_objects $axi_ic_to_host -filter {TYPE == "clk" && DIR == "I"}] \
      [get_bd_pins -of_objects $axi_ic_from_host -filter {TYPE == "clk" && DIR == "I"}] \
      [get_bd_pins $ss_int/aclk] \
      [get_bd_pins $tapasco_status/s00_axi_aclk] \
      [get_bd_pins uArch/host_aclk]

    set design_clk_receivers [list \
      [get_bd_pins $ss_mem/design_clk] \
      [get_bd_pins $ss_reset/design_aclk] \
      [get_bd_pins uArch/design_aclk] \
    ]

    if {[llength [arch::get_masters]] > 0} {
      lappend design_clk_receivers [get_bd_pins -filter { TYPE == "clk" } -of_objects $axi_ic_to_mem]
    }
    connect_bd_net $design_clk $design_clk_receivers

    connect_bd_net $ddr_clk [get_bd_pins $ss_reset/ddr_aclk] [get_bd_pins uArch/memory_aclk]

    # connect PCIe resets
    connect_bd_net -net pcie_aresetn_net [get_bd_pins $ss_pcie/pcie_aresetn] \
      [get_bd_pins $ss_reset/pcie_aresetn] \
      [get_bd_pins $tapasco_status/s00_axi_aresetn]

    connect_bd_net [get_bd_pins $ss_mem/ddr_aresetn] \
      [get_bd_pins $ss_reset/ddr_clk_aresetn] \
      [get_bd_pins $ss_reset/design_clk_aresetn]
    set pcie_p_aresetn [get_bd_pins $ss_reset/pcie_peripheral_aresetn]
    set pcie_ic_aresetn [get_bd_pins $ss_reset/pcie_interconnect_aresetn]

    connect_bd_net $pcie_p_aresetn \
      [get_bd_pins $ss_mem/mem64_aresetn] \
      [get_bd_pins -of_objects $axi_ic_to_host -filter {TYPE == "rst" && DIR == "I" && NAME != "ARESETN"}] \
      [get_bd_pins -of_objects $axi_ic_from_host -filter {TYPE == "rst" && DIR == "I"}] \
      [get_bd_pins $ss_int/peripheral_aresetn] \
      [get_bd_pins $ss_mem/pcie_peripheral_aresetn] \
      [get_bd_pins uArch/host_peripheral_aresetn]

    connect_bd_net $pcie_ic_aresetn \
      [get_bd_pins $axi_ic_to_host/ARESETN] \
      [get_bd_pins $ss_int/interconnect_aresetn] \
      [get_bd_pins uArch/host_interconnect_aresetn]

    # connect ddr_clk resets
    connect_bd_net [get_bd_pins $ss_reset/ddr_clk_peripheral_aresetn] [get_bd_pins $ss_mem/ddr_peripheral_aresetn] [get_bd_pins uArch/memory_peripheral_aresetn]
    connect_bd_net [get_bd_pins $ss_reset/ddr_clk_interconnect_aresetn] [get_bd_pins $ss_mem/ddr_interconnect_aresetn] [get_bd_pins uArch/memory_interconnect_aresetn]

    set design_clk_p_aresetn [get_bd_pins $ss_reset/design_clk_peripheral_aresetn]
    set design_clk_ic_aresetn [get_bd_pins $ss_reset/design_clk_interconnect_aresetn]

    set design_rst_receivers [list \
      [get_bd_pins $ss_mem/design_peripheral_aresetn] \
      [get_bd_pins uArch/design_peripheral_aresetn] \
    ]

    if {[llength [arch::get_masters]] > 0} {
      lappend design_rst_receivers [get_bd_pins -filter {TYPE == "rst" && NAME != "ARESETN"} -of_objects $axi_ic_to_mem]
    }

    connect_bd_net $design_clk_p_aresetn $design_rst_receivers

    connect_bd_net $design_clk_ic_aresetn \
      [get_bd_pins $ss_mem/interconnect_aresetn] \
      [get_bd_pins uArch/design_interconnect_aresetn] \
      [get_bd_pins $axi_ic_to_mem/ARESETN]

    # connect AXI from host to system
    connect_bd_intf_net [get_bd_intf_pins $ss_pcie/m_axi] [get_bd_intf_pins $axi_ic_from_host/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins $axi_ic_from_host/M00_AXI] [get_bd_intf_pins uArch/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins $axi_ic_from_host/M01_AXI] [get_bd_intf_pins $ss_int/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins $axi_ic_from_host/M02_AXI] [get_bd_intf_pins $ss_mem/s_axi_ddma]

    # connect AXI from system to host
    connect_bd_intf_net [get_bd_intf_pins $ss_mem/m_axi_mem64] [get_bd_intf_pins $axi_ic_to_host/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins $ss_int/M_AXI] [get_bd_intf_pins $axi_ic_to_host/S01_AXI]
    connect_bd_intf_net [get_bd_intf_pins $axi_ic_to_host/M00_AXI] [get_bd_intf_pins $ss_pcie/s_axi]

    # call plugins
    tapasco::call_plugins "post-platform"

    create_constraints

    # validate the design
    platform_address_map
    validate_bd_design
    save_bd_design
  }

}
