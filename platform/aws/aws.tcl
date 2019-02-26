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

  namespace export create
  namespace export max_masters
  namespace export create_subsystem_clocks_and_resets
  namespace export create_subsystem_host
  namespace export create_subsystem_memory
  namespace export create_subsystem_intc
  namespace export create_subsystem_tapasco

  if { ! [info exists pcie_width] } {
    puts "No PCIe width defined. Assuming x8..."
    set pcie_width "x8"
  } else {
    puts "Using PCIe width $pcie_width."
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
        "M_DDR"    { foreach {base stride range comp} [list 0x000C00000000 0x000100000000 0x80000000 "PLATFORM_COMPONENT_DDR"] {} }
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

    set clk_inputs [get_bd_pins -of_objects [get_bd_cells \
      -filter {NAME != "mig_7series_0" && NAME != "proc_sys_reset_0"&& NAME != "axi_pcie3_0" && NAME != "pcie_ic"}] \
      -filter { TYPE == "clk" && DIR == "I" && NAME != "refclk"}]

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
    # set msix_interface [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:pcie3_cfg_msix_rtl:1.0 "M_MSIX"]
    set aclk [tapasco::subsystem::get_port "host" "clk"]
    set p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set dma_irq_read [create_bd_pin -type "intr" -dir I "dma_irq_read"]
    set dma_irq_write [create_bd_pin -type "intr" -dir I "dma_irq_write"]

    # TODO using type "undef" instead of "intr" to be compatible with F1 shell
    set irq_output [create_bd_pin -type "undef" -dir O "interrupts"]

    set num_irqs_threadpools [::tapasco::get_platform_num_slots]
    set num_irqs [expr $num_irqs_threadpools + 4]

    set irq_concat_ss [tapasco::ip::create_xlconcat "interrupt_concat" 4]

    connect_bd_net $dma_irq_read [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In0"}]
    connect_bd_net $dma_irq_write [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In1"}]
    puts "Unused Interrupts: 2, 3 are tied to 0"
    set irq_unused [tapasco::ip::create_constant "irq_unused" 1 0]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In2"}]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In3"}]

    # Smartconnect for INTC
    set intc_ic [tapasco::ip::create_axi_sc "intc_ic" 1 4]

    connect_bd_net [get_bd_pins "$intc_ic/aclk"] $aclk
    connect_bd_intf_net [get_bd_intf_pins "$intc_ic/S00_AXI"] $s_axi

    # Concat design interrupts
    set irq_concat_design [tapasco::ip::create_xlconcat "interrupt_concat_design" 5]

    # TODO a total of 16 interrupts are supported, but for now we are not using all of them
    set unused [tapasco::ip::create_constant "irq_unused_design" 8 0]
    connect_bd_net [get_bd_pins $unused/dout] [get_bd_pins "$irq_concat_design/In4"]

    for {set i 0} {$i < 1} {incr i} {
      set port [create_bd_pin -from 31 -to 0 -dir I -type intr "intr_$i"]
      #connect_bd_net $port [get_bd_pin -of_objects $irq_concat_design -filter "NAME == In$i"]

      # Instantiate INTC (each supports 1-32 interrupts)
      #set axi_intc($i) [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 "axi_intc_$i"]
      set axi_intc($i) [tapasco::ip::create_axi_irqc "axi_intc_$i"]
      connect_bd_net $port [get_bd_pins $axi_intc($i)/intr]

      connect_bd_intf_net [get_bd_intf_pins "$intc_ic/M0${i}_AXI"] [get_bd_intf_pins "$axi_intc($i)/s_axi"]

      # Connect output of INTC to InX of Concat
      connect_bd_net [get_bd_pins $axi_intc($i)/irq] [get_bd_pins "$irq_concat_design/In$i"]

      # Connect clocks/resets
      connect_bd_net [get_bd_pins $axi_intc($i)/s_axi_aclk] $aclk
      connect_bd_net [get_bd_pins $axi_intc($i)/s_axi_aresetn] $p_aresetn
    }

    # Set unused interrupts to constant zero
    for {set j $i} {$j < 4} {incr j} {
      set unused [tapasco::ip::create_constant "irq_unused_$j" 1 0]
      connect_bd_net [get_bd_pins $unused/dout] [get_bd_pins "$irq_concat_design/In$j"]
    }

    # Concat DMA and design concat interrupts
    set irq_concat_all [tapasco::ip::create_xlconcat "interrupt_concat_all" 2]

    connect_bd_net [get_bd_pins "$irq_concat_ss/dout"] [get_bd_pins "$irq_concat_all/In0"]
    connect_bd_net [get_bd_pins "$irq_concat_design/dout"] [get_bd_pins "$irq_concat_all/In1"]

    connect_bd_net [get_bd_pins "$irq_concat_all/dout"] $irq_output

    save_bd_design

    #connect_bd_net [get_bd_pin -of_objects $irq_concat_design -filter {NAME == "dout"}] [get_bd_pin -of_objects $msix_intr_ctrl -filter {NAME == "interrupt_design"}]

    # connect internal clocks
    #connect_bd_net $aclk [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI_ACLK"}]
    #connect_bd_net $design_aclk [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "design_clk"}]
    #connect_bd_net $p_aresetn [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI_ARESETN"}]
    #connect_bd_net $design_aresetn [get_bd_pins -of_objects $msix_intr_ctrl -filter {NAME == "design_rst"}]

    # connect S_AXI
    #connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $msix_intr_ctrl -filter {NAME == "S_AXI"}]
  }

  # Creates the memory subsystem consisting of MIG core for DDR RAM,
  # and a DMA engine which is connected to the MIG and has an
  # external 64bit M_AXI channel toward PCIe.
  proc create_subsystem_memory {} {

    # # create hierarchical interface ports
    # Moved to host subsystem
    # set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_0"]

    set m_axi_mem [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_HOST"]
    set s_axi_ddma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA"]

    # # create hierarchical ports: clocks
    # set ddr_aclk [create_bd_pin -type "clk" -dir "O" "ddr_aclk"]
    # set design_clk [create_bd_pin -type "clk" -dir "O" "design_aclk"]
    set pcie_aclk [tapasco::subsystem::get_port "host" "clk"]
    # set design_aclk [tapasco::subsystem::get_port "design" "clk"]

    # # create hierarchical ports: resets
    # set ddr_aresetn [create_bd_pin -type "rst" -dir "O" "ddr_aresetn"]
    # set design_aresetn [create_bd_pin -type "rst" -dir "O" "design_aresetn"]
    set pcie_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    # set ddr_ic_aresetn [tapasco::subsystem::get_port "mem" "rst" "interconnect"]
    # set ddr_p_aresetn  [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
    # set design_p_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    set irq_read [create_bd_pin -type "intr" -dir "O" "dma_irq_read"]
    set irq_write [create_bd_pin -type "intr" -dir "O" "dma_irq_write"]

    # variable pcie_width
    #if { $pcie_width == "x8" } {
      set dma [tapasco::ip::create_bluedma "dma"]
    #} else {
    #  set dma [tapasco::ip::create_bluedma_x16 "dma"]
    #}
    connect_bd_net [get_bd_pins $dma/IRQ_read] $irq_read
    connect_bd_net [get_bd_pins $dma/IRQ_write] $irq_write

    # set mig_ic [tapasco::ip::create_axi_sc "mig_ic" 2 1]
    # tapasco::ip::connect_sc_default_clocks $mig_ic "mem"

    # # AXI connections:
    # # connect dma 32bit to mig_ic
    # connect_bd_intf_net [get_bd_intf_pins $dma/M32_AXI] [get_bd_intf_pins mig_ic/S00_AXI]

    # connect DMA 64bit to external port
    connect_bd_intf_net [get_bd_intf_pins $dma/M64_AXI] $m_axi_mem

    # # connect second mig_ic slave to external port
    # connect_bd_intf_net $s_axi_mem [get_bd_intf_pins mig_ic/S01_AXI]

    # connect DMA S_AXI to external port
    connect_bd_intf_net $s_axi_ddma [get_bd_intf_pins $dma/S_AXI]

    # create port for access to DDR memory
    set m_ddr [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DDR"]

    connect_bd_intf_net $m_ddr [get_bd_intf_pins "$dma/m32_axi"]


    # connect PCIe clock and reset
    connect_bd_net $pcie_aclk \
      [get_bd_pins $dma/m32_axi_aclk] [get_bd_pins $dma/m64_axi_aclk] [get_bd_pins $dma/s_axi_aclk]

    connect_bd_net $pcie_p_aresetn \
      [get_bd_pins $dma/m32_axi_aresetn] [get_bd_pins $dma/m64_axi_aresetn] [get_bd_pins $dma/s_axi_aresetn]

    # # connect DDR clock and reset
    # set ddr_clk [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk]
    # connect_bd_net [tapasco::subsystem::get_port "mem" "clk"] \
    #   [get_bd_pins $dma/m32_axi_aclk]
    # connect_bd_net $ddr_p_aresetn \
    #   [get_bd_pins $dma/m32_axi_aresetn] \
    #   [get_bd_pins -regexp mig/(c0_ddr4_)?aresetn]

    # # connect external DDR clk/rst output ports
    # connect_bd_net $ddr_clk $ddr_aclk

    # if {[get_property CONFIG.POLARITY [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk_sync_rst]] == "ACTIVE_HIGH"} {
    #     set ddr_rst_inverter [tapasco::ip::create_logic_vector "ddr_rst_inverter"]
    #     set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $ddr_rst_inverter]
    #     connect_bd_net [get_bd_pins $ddr_rst_inverter/Op1] [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk_sync_rst]
    #     connect_bd_net [get_bd_pins $ddr_rst_inverter/Res] $ddr_aresetn
    # } else {
    #     connect_bd_net $ddr_aresetn [get_bd_pins -regexp mig/(c0_ddr4_)?ui_clk_sync_rst]
    # }
  }

  proc create_subsystem_host {} {
    variable pcie_width

    set device_type [get_property ARCHITECTURE [get_parts -of_objects [current_project]]]
    puts "Device type is $device_type"

    puts "Creating PCIe subsystem ..."

    # create hierarchical ports
    set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_HOST"]
    set m_arch [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_ARCH"]
    set m_intc [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_INTC"]
    set m_tapasco [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_TAPASCO"]
    set m_dma [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DMA"]
    set pcie_aclk [create_bd_pin -type "clk" -dir "O" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "O" "pcie_aresetn"]
    #set msix_interface [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:pcie3_cfg_msix_rtl:1.0 "S_MSIX"]

    # TODO using type "undef" instead of "intr" to be compatible with F1 shell
    set irq_input [create_bd_pin -type "undef" -dir I "interrupts"]

    # create instances of shell
    set f1_inst [create_f1_shell]

    # TODO: WARNING: [BD 41-1731] Type mismatch between connected pins: /host/interrupts(intr) and /host/f1_inst/irq_req(undef)
    connect_bd_net $irq_input [get_bd_pins "$f1_inst/irq_req"]

    # create clocking wizard instance and ports
    set design_clk_wiz [tapasco::ip::create_clk_wiz design_clk_wiz]
    set_property -dict [list CONFIG.CLK_OUT1_PORT {design_clk} \
                        CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [tapasco::get_design_frequency] \
                        CONFIG.USE_LOCKED {true} \
                        CONFIG.USE_RESET {true} \
                        CONFIG.RESET_TYPE {ACTIVE_LOW} \
                        CONFIG.RESET_PORT {resetn} \
                        ] $design_clk_wiz

    set design_aclk [create_bd_pin -type "clk" -dir "O" "design_aclk"]
    set design_aresetn [create_bd_pin -type "rst" -dir "O" "design_aresetn"]

    connect_bd_net [get_bd_pins $design_clk_wiz/resetn] [get_bd_pins "$f1_inst/rst_main_n_out"]
    connect_bd_net [get_bd_pins $design_clk_wiz/clk_in1] [get_bd_pins "$f1_inst/clk_main_a0_out"]

    # connect external design clk
    connect_bd_net [get_bd_pins $design_clk_wiz/design_clk] $design_aclk
    connect_bd_net [get_bd_pins $design_clk_wiz/locked] $design_aresetn

    # Connect DDR ports
    set ddr_ic [tapasco::ip::create_axi_sc "ddr_ic" 2 4]
    tapasco::ip::connect_sc_default_clocks $ddr_ic "host"

    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/M00_AXI"] [get_bd_intf_pins "$f1_inst/S_AXI_DDRA"]
    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/M01_AXI"] [get_bd_intf_pins "$f1_inst/S_AXI_DDRB"]
    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/M02_AXI"] [get_bd_intf_pins "$f1_inst/S_AXI_DDRC"]
    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/M03_AXI"] [get_bd_intf_pins "$f1_inst/S_AXI_DDRD"]

    set s_ddr [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DDR"]

    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/S00_AXI"] $s_ddr

    # This was part of the memory subsystem and moved here
    set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_0"]

    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/S01_AXI"] $s_axi_mem

    # Connect "out" AXI ports
    set out_ic [tapasco::ip::create_axi_sc "out_ic" 1 4]
    tapasco::ip::connect_sc_default_clocks $out_ic "design"

    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M00_AXI}] $m_arch
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M01_AXI}] $m_intc
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M02_AXI}] $m_tapasco
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M03_AXI}] $m_dma

    connect_bd_intf_net [get_bd_intf_pins "$out_ic/S00_AXI"] [get_bd_intf_pins "$f1_inst/M_AXI_PCIS"]

    # Connect "in" AXI ports
    set in_ic [tapasco::ip::create_axi_sc "in_ic" 2 1]
    tapasco::ip::connect_sc_default_clocks $in_ic "host"

    connect_bd_intf_net [get_bd_intf_pins S_HOST] [get_bd_intf_pins $in_ic/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins -of_object $in_ic -filter { MODE == Master }] \
       [get_bd_intf_pins "$f1_inst/S_AXI_PCIM"]

    save_bd_design

    # set trans [get_bd_cells -filter {NAME == "MSIxTranslator"}]
    # if { $trans != "" } {
    #     connect_bd_intf_net $msix_interface [get_bd_intf_pins $trans/fromMSIxController]
    # } else {
    #     connect_bd_intf_net $msix_interface [get_bd_intf_pins $pcie/pcie_cfg_msix]
    # }

    # set out_ic [tapasco::ip::create_axi_sc "out_ic" 1 4]
    # tapasco::ip::connect_sc_default_clocks $out_ic "design"

    # if {$device_type != "virtexuplus"} {
    #   if { $pcie_width == "x8" } {
    #     puts "Using PCIe IP for x8..."
    #     set bridge [tapasco::ip::create_pciebridgetolite "PCIeBridgeToLite"]
    #   } else {
    #     puts "Using PCIe IP for x16..."
    #     set bridge [tapasco::ip::create_pciebridgetolite_x16 "PCIeBridgeToLite"]
    #   }
    #     connect_bd_intf_net [get_bd_intf_pins -regexp $pcie/M_AXI(_B)?] \
    #   [get_bd_intf_pins -of_objects $bridge -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]

    #   connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] [get_bd_pins -of_objects $bridge -filter "TYPE == clk"]
    #   connect_bd_net [get_bd_pins axi_pcie3_0/axi_aresetn] [get_bd_pins -of_objects $bridge -filter "TYPE == rst"]

    #   connect_bd_intf_net [get_bd_intf_pins -of_objects $bridge -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Master"] \
    #   [get_bd_intf_pins -of_objects $out_ic -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]
    # } else {
    #   connect_bd_intf_net [get_bd_intf_pins -regexp $pcie/M_AXI(_B)?] \
    #     [get_bd_intf_pins -of_objects $out_ic -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]
    # }

    # set in_ic [tapasco::ip::create_axi_sc "in_ic" 2 1]
    # tapasco::ip::connect_sc_default_clocks $in_ic "host"

    # connect_bd_intf_net [get_bd_intf_pins S_HOST] [get_bd_intf_pins $in_ic/S00_AXI]
    # connect_bd_intf_net [get_bd_intf_pins -of_object $in_ic -filter { MODE == Master }] \
    #   [get_bd_intf_pins -regexp $pcie/S_AXI(_B)?]

    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M00_AXI}] $m_arch
    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M01_AXI}] $m_intc
    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M02_AXI}] $m_tapasco
    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M03_AXI}] $m_dma

    # forward PCIe clock to external ports
    # connect_bd_net [get_bd_pins axi_pcie3_0/axi_aclk] $pcie_aclk

    # connect_bd_net [get_bd_pins axi_pcie3_0/axi_aresetn] $pcie_aresetn
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

  proc create_f1_shell {} {

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

    set_property ip_repo_paths  "[get_property ip_repo_paths [current_project]] \
        [file join $::env(AWS_FPGA_REPO_DIR)/hdk/common/shell_stable/hlx/design/ip/aws_v1_0]" [current_project]

    update_ip_catalog

      # Create interface ports
    set S_SH [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aws_f1_sh1_rtl:1.0 S_SH ]

    # Create instance: f1_inst, and set properties
    set f1_inst [ create_bd_cell -type ip -vlnv xilinx.com:ip:aws:1.0 f1_inst ]
    set_property -dict [ list \
        CONFIG.AUX_PRESENT {1} \
        CONFIG.BAR1_PRESENT {0} \
        CONFIG.CLOCK_A0_FREQ {125000000} \
        CONFIG.CLOCK_A1_FREQ {62500000} \
        CONFIG.CLOCK_A2_FREQ {187500000} \
        CONFIG.CLOCK_A3_FREQ {250000000} \
        CONFIG.CLOCK_A_RECIPE {0} \
        CONFIG.DEVICE_ID {0xF000} \
        CONFIG.PCIS_PRESENT {1} \
        CONFIG.PCIM_PRESENT {1} \
        CONFIG.AUX_PRESENT {1} \
        CONFIG.DDR_A_PRESENT {1} \
        CONFIG.DDR_B_PRESENT {1} \
        CONFIG.DDR_C_PRESENT {1} \
        CONFIG.DDR_D_PRESENT {1} \
        CONFIG.OCL_PRESENT {0} \
        CONFIG.SDA_PRESENT {0} \
    ] $f1_inst

    set ddr_aclk [create_bd_pin -type "clk" -dir "O" "ddr_aclk"]
    set ddr_aresetn [create_bd_pin -type "rst" -dir "O" "ddr_aresetn"]

    # Connect S_SH pin
    set oldCurInst [current_bd_instance .]
    current_bd_instance
    connect_bd_intf_net $S_SH [get_bd_intf_pins $f1_inst/S_SH]
    current_bd_instance $oldCurInst

    connect_bd_net [get_bd_pins "pcie_aclk"] [get_bd_pins "$f1_inst/clk_main_a0_out"]
    connect_bd_net [get_bd_pins "pcie_aresetn"] [get_bd_pins "$f1_inst/rst_main_n_out"]

    connect_bd_net $ddr_aclk [get_bd_pins "$f1_inst/clk_main_a0_out"]
    connect_bd_net $ddr_aresetn [get_bd_pins "$f1_inst/rst_main_n_out"]

    # Required later (manifest file)

    # set timestamp [exec date +"%y_%m_%d-%H%M%S"]
    # # FIXME - grep 'HDK_VERSION' $HDK_DIR/hdk_version.txt | sed 's/=/ /g' | awk '{print $2}'
    # set hdk_version 1.4.5
    # # FIXME - grep 'SHELL_VERSION' $HDK_SHELL_DIR/shell_version.txt | sed 's/=/ /g' | awk '{print $2}'
    # # set shell_version 0x04261818

    # set clock_recipe_a [get_property CONFIG.CLOCK_A_RECIPE [get_bd_cells $f1_inst]]
    # set clock_recipe_b [get_property CONFIG.CLOCK_B_RECIPE [get_bd_cells $f1_inst]]
    # set clock_recipe_c [get_property CONFIG.CLOCK_C_RECIPE [get_bd_cells $f1_inst]]

    # set device_id [get_property CONFIG.DEVICE_ID [get_bd_cells $f1_inst]]
    # set vendor_id [get_property CONFIG.VENDOR_ID [get_bd_cells $f1_inst]]
    # set subsystem_id [get_property CONFIG.SUBSYSTEM_ID [get_bd_cells $f1_inst]]
    # set subsystem_vendor_id [get_property CONFIG.SUBSYSTEM_VENDOR_ID [get_bd_cells $f1_inst]]

    # set faas_shell_version [get_property CONFIG.SHELL_VERSION [get_bd_cells $f1_inst]]
    # set shell_version $faas_shell_version

    # set ::env(CLOCK_A_RECIPE) $clock_recipe_a
    # set ::env(CLOCK_B_RECIPE) $clock_recipe_b
    # set ::env(CLOCK_C_RECIPE) $clock_recipe_c

    # set ::env(device_id) $device_id
    # set ::env(vendor_id) $vendor_id
    # set ::env(subsystem_id) $subsystem_id
    # set ::env(subsystem_vendor_id) $subsystem_vendor_id

    # set ::env(FAAS_SHELL_VERSION) $faas_shell_version

    # Create address segments
    # /host/f1_inst/S_AXI_DDRA/Mem_DDRA

    # create_bd_addr_seg -range 0x80000000 -offset 0x000C00000000 [get_bd_addr_spaces $f1_inst/M_AXI_PCIS] [get_bd_addr_segs $f1_inst/S_AXI_DDRA/Mem_DDRA] SEG_aws_0_Mem_DDRA
    # create_bd_addr_seg -range 0x80000000 -offset 0x000D00000000 [get_bd_addr_spaces $f1_inst/M_AXI_PCIS] [get_bd_addr_segs $f1_inst/S_AXI_DDRB/Mem_DDRB] SEG_aws_0_Mem_DDRB
    # create_bd_addr_seg -range 0x80000000 -offset 0x000E00000000 [get_bd_addr_spaces $f1_inst/M_AXI_PCIS] [get_bd_addr_segs $f1_inst/S_AXI_DDRC/Mem_DDRC] SEG_aws_0_Mem_DDRC
    # create_bd_addr_seg -range 0x80000000 -offset 0x000F00000000 [get_bd_addr_spaces $f1_inst/M_AXI_PCIS] [get_bd_addr_segs $f1_inst/S_AXI_DDRD/Mem_DDRD] SEG_aws_0_Mem_DDRD
    # create_bd_addr_seg -range 0x00010000 -offset 0x00000000 [get_bd_addr_spaces $f1_inst/M_AXI_BAR1] [get_bd_addr_segs axi_cdma_0/S_AXI_LITE/Reg] SEG_axi_cdma_0_Reg
    # create_bd_addr_seg -range 0x00001000 -offset 0x00000000 [get_bd_addr_spaces $f1_inst/M_AXI_SDA] [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg
    # create_bd_addr_seg -range 0x00001000 -offset 0x00000000 [get_bd_addr_spaces $f1_inst/M_AXI_OCL] [get_bd_addr_segs axi_gpio_1/S_AXI/Reg] SEG_axi_gpio_1_Reg
    # create_bd_addr_seg -range 0x80000000 -offset 0x000C00000000 [get_bd_addr_spaces axi_cdma_0/Data] [get_bd_addr_segs $f1_inst/S_AXI_DDRA/Mem_DDRA] SEG_aws_0_Mem_DDRA
    # create_bd_addr_seg -range 0x80000000 -offset 0x000D00000000 [get_bd_addr_spaces axi_cdma_0/Data] [get_bd_addr_segs $f1_inst/S_AXI_DDRB/Mem_DDRB] SEG_aws_0_Mem_DDRB
    # create_bd_addr_seg -range 0x80000000 -offset 0x000E00000000 [get_bd_addr_spaces axi_cdma_0/Data] [get_bd_addr_segs $f1_inst/S_AXI_DDRC/Mem_DDRC] SEG_aws_0_Mem_DDRC
    # create_bd_addr_seg -range 0x80000000 -offset 0x000F00000000 [get_bd_addr_spaces axi_cdma_0/Data] [get_bd_addr_segs $f1_inst/S_AXI_DDRD/Mem_DDRD] SEG_aws_0_Mem_DDRD

    return $f1_inst
  }

  # namespace eval aws {
  #     namespace export addressmap

  #     proc addressmap {args} {
  #         set args [lappend args "Mem_DDRA" [list 0x000C00000000 0 0 ""]]
  #         set args [lappend args "S_AXI_DDRB" [list 0x000D00000000 0 0 ""]]
  #         set args [lappend args "S_AXI_DDRC" [list 0x000E00000000 0 0 ""]]
  #         set args [lappend args "S_AXI_DDRD" [list 0x000F00000000 0 0 ""]]
  #         return $args
  #     }
  # }

  # tapasco::register_plugin "platform::aws::addressmap" "post-address-map"
}
