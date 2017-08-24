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
# @file		vcu118.tcl
# @brief	VCU118 platform implementation.
# @author	J. A. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
#
namespace eval platform {
  namespace export create
  namespace export max_masters

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/vcu118/plugins" "*.tcl"] {
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
    set dma_irq [create_bd_pin -type "intr" -dir I "dma_irq"]

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

    connect_bd_net $dma_irq [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In0"}]
    puts "Unused Interrupts: 1, 2, 3 are tied to 0"
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In1"}]
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
    set irq [create_bd_pin -type "intr" -dir "O" "dma_irq"]

    # create instances of cores: MIG core, dual DMA, system cache
    set mig [create_mig_core "mig"]
    dict set tapasco::stdcomps dualdma vlnv "esa.informatik.tu-darmstadt.de:user:BlueDMA:1.0"
    set dual_dma [tapasco::createDualDMA "dual_dma"]
    set mig_ic [tapasco::createSmartConnect "mig_ic" 2 1]

    # no cache - connect directly to MIG
    connect_bd_intf_net [get_bd_intf_pins $mig_ic/M00_AXI] [get_bd_intf_pins $mig/C0_DDR4_S_AXI]

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
    set ddr_clk [get_bd_pins mig/c0_ddr4_ui_clk]
    connect_bd_net -net ddr_clk_net $ddr_clk \
      [get_bd_pins mig_ic/aclk] \
      [get_bd_pins dual_dma/m32_axi_aclk]
    connect_bd_net -net ddr_p_rst_net $ddr_p_aresetn \
      [get_bd_pins dual_dma/m32_axi_aresetn] \
      [get_bd_pins mig/c0_ddr4_aresetn]

    # connect external DDR clk/rst output ports
    connect_bd_net [get_bd_pins mig/c0_ddr4_ui_clk_sync_rst] $ddr_aresetn
    connect_bd_net [get_bd_pins mig/c0_ddr4_ui_clk] $ddr_aclk

    # connect internal design clk/rst
    connect_bd_net -net design_clk_net $design_aclk [get_bd_pins mig_ic/S01_ACLK]
    connect_bd_net -net design_rst_net $design_p_aresetn [get_bd_pins mig_ic/S01_ARESETN]

    # connect external design clk
    set ext_design_clk [get_bd_pins mig/c0_ddr4_ui_clk]
    if {[tapasco::get_design_frequency] != [tapasco::get_mem_frequency]} {
      puts "Setting design clock to [tapasco::get_design_frequency] MHz"
      set clk_wiz [tapasco::createClockingWizard "design_clk_generator"]
      set_property -dict [list CONFIG.CLK_IN1_BOARD_INTERFACE {sysclk_125} \
                               CONFIG.RESET_BOARD_INTERFACE {reset} \
                               CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [tapasco::get_design_frequency] \
                               CONFIG.PRIM_SOURCE {Differential_clock_capable_pin}] $clk_wiz
      apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface "sysclk_125 ( 125 MHz System differential clock ) " }  [get_bd_intf_pins $clk_wiz/CLK_IN1_D]
      connect_bd_net [get_bd_pins sys_rst]  [get_bd_pins $clk_wiz/reset]
      set ext_design_clk [get_bd_pins $clk_wiz/clk_out1]
    }
    connect_bd_net $ext_design_clk $design_clk

    # connect IRQ
    connect_bd_net [get_bd_pins dual_dma/IRQ] $irq

    current_bd_instance $instance
    return $group
  }

  proc create_mig_core {name} {
    puts "Creating MIG core for DDR ..."
    set mig [create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 $name]
    apply_board_connection -board_interface "ddr4_sdram_c1" -ip_intf "$name/C0_DDR4" -diagram "system"
    apply_board_connection -board_interface "default_250mhz_clk1" -ip_intf "$name/C0_SYS_CLK" -diagram "system"
    apply_board_connection -board_interface "reset" -ip_intf "$name/SYSTEM_RESET" -diagram "system"
    return $mig
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
    connect_bd_intf_net $s_axi [get_bd_intf_pins axi_pcie3_0/S_AXI_B]
    # connect PCIe master to external port
    connect_bd_intf_net [get_bd_intf_pins axi_pcie3_0/M_AXI_B] [get_bd_intf_pins mm_to_lite_slice_before/S_AXI]
    # connect mm_to_lite datawidth converter to protocol converter
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_before/M_AXI] [get_bd_intf_pins mm_to_lite_dwidth/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_dwidth/M_AXI] [get_bd_intf_pins mm_to_lite_slice_mid/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_mid/M_AXI] [get_bd_intf_pins mm_to_lite_proto/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_proto/M_AXI] [get_bd_intf_pins mm_to_lite_slice_after/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins mm_to_lite_slice_after/M_AXI] $m_axi

    # connect msix signals to external ports
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_enable] $msix_enable
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_mask] $msix_mask
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msi_fail] $msix_fail
    connect_bd_net [get_bd_pins axi_pcie3_0/cfg_interrupt_msi_sent] $msix_sent

    connect_bd_net $msix_addr [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_address]
    connect_bd_net $msix_data [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_data]
    connect_bd_net $msix_int [get_bd_pins axi_pcie3_0/cfg_interrupt_msix_int]

    # forward PCIe clock to external ports
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] $pcie_aclk [get_bd_pins mm_to_lite_dwidth/s_axi_aclk] [get_bd_pins mm_to_lite_proto/aclk] [get_bd_pins mm_to_lite_slice_before/aclk] [get_bd_pins mm_to_lite_slice_mid/aclk] [get_bd_pins mm_to_lite_slice_after/aclk]
    connect_bd_net [get_bd_pins axi_pcie3_0/axi_aresetn] $pcie_aresetn [get_bd_pins mm_to_lite_dwidth/s_axi_aresetn] [get_bd_pins mm_to_lite_proto/aresetn] [get_bd_pins mm_to_lite_slice_before/aresetn] [get_bd_pins mm_to_lite_slice_mid/aresetn] [get_bd_pins mm_to_lite_slice_after/aresetn]

    current_bd_instance $instance
    return $group
  }

  proc create_pcie_core {} {
    puts "Creating AXI PCIe Gen3 bridge ..."
    # create PCIe core
    set axi_pcie3_0 [tapasco::createPCIeBridge "axi_pcie3_0" true]
    set pcie_properties [list \
      CONFIG.functional_mode {AXI_Bridge} \
      CONFIG.mode_selection {Advanced} \
      CONFIG.pl_link_cap_max_link_width {X8} \
      CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
      CONFIG.axi_addr_width {64} \
      CONFIG.pipe_sim {true} \
      CONFIG.pf0_revision_id {01} \
      CONFIG.pf0_base_class_menu {Memory_controller} \
      CONFIG.pf0_sub_class_interface_menu {Other_memory_controller} \
      CONFIG.pf0_interrupt_pin {NONE} CONFIG.pf0_msi_enabled {false} \
      CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
      CONFIG.PCIE_BOARD_INTERFACE {pci_express_x8} \
      CONFIG.pf0_msix_enabled {true} \
      CONFIG.c_m_axi_num_write {32} \
      CONFIG.pf0_msix_impl_locn {External} \
      CONFIG.pf0_bar0_size {64} \
      CONFIG.pf0_bar0_scale {Megabytes} \
      CONFIG.pf0_bar0_64bit {true} \
      CONFIG.axi_data_width {256_bit} \
      CONFIG.pf0_device_id {7038} \
      CONFIG.pf0_class_code_base {05} \
      CONFIG.pf0_class_code_sub {80} \
      CONFIG.pf0_class_code_interface {00} \
      CONFIG.xdma_axilite_slave {true} \
      CONFIG.coreclk_freq {500} \
      CONFIG.plltype {QPLL1} \
      CONFIG.pf0_msix_cap_table_size {83} \
      CONFIG.pf0_msix_cap_table_offset {500000} \
      CONFIG.pf0_msix_cap_table_bir {BAR_1:0} \
      CONFIG.pf0_msix_cap_pba_offset {508000} \
      CONFIG.pf0_msix_cap_pba_bir {BAR_1:0} \
      CONFIG.bar_indicator {BAR_1:0} \
      CONFIG.bar0_indicator {0}
      ]

    set_property -dict $pcie_properties $axi_pcie3_0
    apply_bd_automation -rule xilinx.com:bd_rule:xdma \
      -config {auto_level "IP Level" \
               lane_width "X8" \
               link_speed "8.0 GT/s (PCIe Gen 3)" \
               axi_clk "Maximum Data Width" \
               axi_intf "AXI Memory Mapped" \
               bar_size "Disable" \
               bypass_size "Disable" \
               h2c "4" c2h "4" }  \
               $axi_pcie3_0

    return $axi_pcie3_0
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
    set master_addr_space [get_bd_addr_spaces "/PCIe/axi_pcie3_0/M_AXI_B"]
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
      set ts [get_bd_addr_segs /PCIe/axi_pcie3_0/S_AXI_B/BAR0]
      create_bd_addr_seg -range 16E -offset 0 $ms $ts "SEG_$ms"

      set ms [get_bd_addr_spaces $dma/M32_AXI]
      set ts [get_bd_addr_segs /Memory/mig/*]
      create_bd_addr_seg -range 4G -offset 0 $ms $ts "SEG_$ms"
    }

    set int_ms [get_bd_addr_spaces /InterruptControl/msix_intr_ctrl/M_AXI]
    set ts [get_bd_addr_segs /PCIe/axi_pcie3_0/S_AXI_B/BAR0]
    create_bd_addr_seg -range 16E -offset 0 $int_ms $ts "SEG_intr"

    # connect user IP
    set usrs [lsort [get_bd_addr_spaces /uArch/* -filter { NAME =~ "*m_axi*" || NAME =~ "*M_AXI*" }]]
    set ts [get_bd_addr_segs /Memory/mig/*]
    foreach u $usrs {
      create_bd_addr_seg -range [get_property RANGE $u] -offset 0 $u $ts "SEG_$u"
    }
  }

  proc platform_address_map {} {
    platform_address_map_set

    # call plugins
    tapasco::call_plugins "post-address-map"
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
    connect_bd_net [get_bd_pins $ss_mem/dma_irq] [get_bd_pins $ss_int/dma_irq]

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
      [get_bd_pins uArch/design_aclk]
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

    create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.0 PCIe/system_ila_0
    connect_bd_intf_net [get_bd_intf_pins PCIe/system_ila_0/SLOT_0_AXI] [get_bd_intf_pins PCIe/axi_pcie3_0/S_AXI_B]
    connect_bd_net [get_bd_pins PCIe/system_ila_0/clk] [get_bd_pins PCIe/axi_pcie3_0/axi_aclk]
    connect_bd_net [get_bd_pins PCIe/system_ila_0/resetn] [get_bd_pins PCIe/axi_pcie3_0/axi_aresetn]

    # validate the design
    save_bd_design
    puts "Creating address map..."
    platform_address_map
    puts "Validating design..."
    validate_bd_design
    puts "Done! Saving..."
    save_bd_design
  }
}
