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
# @author	M. Ober, TU Darmstadt (tapasco@ober-mail.de)
#
namespace eval platform {

  set platform_dirname "aws"
  set pcie_width "x16"

  variable bd_design_name
  set bd_design_name "cl"

  # Instead of a bitstream, a tarfile is generated which is then
  # processed by AWS in order to generate a loadable AFI.
  variable disable_write_bitstream
  set disable_write_bitstream true

  # Using OOC synthesis is mandatory for this platform.
  variable ooc_synth_mode
  set ooc_synth_mode true

  namespace export create
  namespace export max_masters
  namespace export create_subsystem_clocks_and_resets
  namespace export create_subsystem_host
  namespace export create_subsystem_memory
  namespace export create_subsystem_intc
  namespace export create_subsystem_tapasco

  namespace export generate_wrapper

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
        "M_DMA"     { foreach {base stride range comp} [list 0x00004000 0x2000 0      "PLATFORM_COMPONENT_DMA0"] {} }
        "M_INTC"    { foreach {base stride range comp} [list 0x00006000 0x2000 0      "PLATFORM_COMPONENT_INTC0"] {} }
        "M_MSIX"    { foreach {base stride range comp} [list 0          0       $max64 "PLATFORM_COMPONENT_MSIX0"] {} }
        "M_TAPASCO" { foreach {base stride range comp} [list 0x00000000 0       0      "PLATFORM_COMPONENT_STATUS"] {} }
        "M_HOST"    { foreach {base stride range comp} [list 0          0       $max64 ""] {} }
        "M_MEM_0"    { foreach {base stride range comp} [list 0          0       $max64 ""] {} }
        "M_ARCH"    { set base "skip" }
        "M_DDR"    { foreach {base stride range comp} [list 0 0 0 ""] {} }
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
    set num_design_irqs 0
    foreach irq_port $irqs {
      set i [expr [get_property LEFT $irq_port] + 1]
      puts "Interrupt line $irq_port width is $i"
      incr num_design_irqs $i
    }

    puts "Connecting $num_design_irqs design interrupt(s)..."

    set s_axi [create_bd_intf_pin -mode Slave -vlnv [tapasco::ip::get_vlnv "aximm_intf"] "S_INTC"]
    set aclk [tapasco::subsystem::get_port "host" "clk"]
    set p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set ic_aresetn [::tapasco::subsystem::get_port "host" "rst" "interconnect"]

    set dma_irq_read [create_bd_pin -type "intr" -dir I "dma_irq_read"]
    set dma_irq_write [create_bd_pin -type "intr" -dir I "dma_irq_write"]

    # TODO using type "undef" instead of "intr" to be compatible with F1 shell
    set irq_output [create_bd_pin -from 15 -to 0 -type "undef" -dir O "interrupts"]

    # set num_irqs_threadpools [::tapasco::get_platform_num_slots]
    # set num_irqs [expr $num_irqs_threadpools + 4]

    set irq_concat_ss [tapasco::ip::create_xlconcat "interrupt_concat" 4]

    # Connect DMA interrupts
    connect_bd_net $dma_irq_read [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In0"}]
    connect_bd_net $dma_irq_write [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In1"}]
    puts "Unused Interrupts: 2, 3 are tied to 0"
    set irq_unused [tapasco::ip::create_constant "irq_unused" 1 0]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In2"}]
    connect_bd_net [get_bd_pin -of_object $irq_unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In3"}]


    # if {$num_design_irqs <= 12} {
    #   set port [create_bd_pin -from [expr $num_design_irqs - 1] -to 0 -dir I -type intr "intr_0"]
    #   connect_bd_net $port [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In4"}]

    #   if {$num_design_irqs < 12} {
    #     # Tief off unused interrupts to avoid critical warning about width mismatch
    #     set unused [tapasco::ip::create_constant "irq_unused_design" [expr 12 - $num_design_irqs] 0]
    #     connect_bd_net [get_bd_pin -of_object $unused -filter {NAME == "dout"}] [get_bd_pin -of_objects $irq_concat_ss -filter {NAME == "In5"}]
    #   } {
    #     # Width is matching, remove unused input
    #     set_property -dict [list CONFIG.NUM_PORTS {5}] $irq_concat_ss
    #   }
    # } {
    #   puts "Cannot connect $num_design_irqs interrupts"
    #   exit 1
    # }

    # Smartconnect for INTC
    set intc_ic [tapasco::ip::create_axi_ic "intc_ic" 1 [llength $irqs]]
    # clocks
    connect_bd_net -net intc_clock_net $aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I"}]
    # resets
    set ic_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV =~ "*:axi_interconnect:*"}] -filter {NAME == "ARESETN"}]
    connect_bd_net -net intc_ic_reset_net $ic_aresetn $ic_resets
    # peripheral resets
    set p_resets [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN"}]
    connect_bd_net -net intc_p_reset_net $p_aresetn $p_resets

    connect_bd_intf_net [get_bd_intf_pins -of_objects $intc_ic -filter {NAME == "S00_AXI"}] $s_axi

    # Concat design interrupts
    set irq_concat_design [tapasco::ip::create_xlconcat "interrupt_concat_design" 5]

    set unused [tapasco::ip::create_constant "irq_unused_design" 8 0]
    connect_bd_net [get_bd_pins $unused/dout] [get_bd_pins "$irq_concat_design/In4"]

    for {set i 0} {$i < [llength $irqs]} {incr i} {
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

    # Tie off unused inputs (when using less than 4 axi intc)
    if {$i < 3} {
      for {set j $i} {$j < 4} {incr j} {
        set unused [tapasco::ip::create_constant "irq_unused_$j" 1 0]
        connect_bd_net [get_bd_pins $unused/dout] [get_bd_pins "$irq_concat_design/In$j"]
      }
    }

    # Concat DMA and design concat interrupts
    set irq_concat_all [tapasco::ip::create_xlconcat "interrupt_concat_all" 2]

    connect_bd_net [get_bd_pins "$irq_concat_ss/dout"] [get_bd_pins "$irq_concat_all/In0"]
    connect_bd_net [get_bd_pins "$irq_concat_design/dout"] [get_bd_pins "$irq_concat_all/In1"]

    connect_bd_net [get_bd_pins -of_object $irq_concat_all -filter {NAME == "dout"}] $irq_output
    # connect_bd_net [get_bd_pin -of_object $irq_concat_ss -filter {NAME == "dout"}] $irq_output
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

    variable pcie_width
    if { $pcie_width == "x8" } {
      set dma [tapasco::ip::create_bluedma "dma"]
    } else {
      set dma [tapasco::ip::create_bluedma_x16 "dma"]
    }
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
  }

  proc create_subsystem_host {} {
    variable pcie_width

    set device_type [get_property ARCHITECTURE [get_parts -of_objects [current_project]]]
    puts "Device type is $device_type"

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
    connect_bd_net [get_bd_pins $design_clk_wiz/clk_in1] [get_bd_pins "$f1_inst/clk_extra_a1_out"]

    # connect external design clk
    connect_bd_net [get_bd_pins $design_clk_wiz/design_clk] $design_aclk
    connect_bd_net [get_bd_pins $design_clk_wiz/locked] $design_aresetn

    # Connect DDR ports (DDR C is inside the Shell and should always be available)
    set ddr_available {}
    foreach x {A B C D} {
      if {[get_property "CONFIG.DDR_${x}_PRESENT" $f1_inst] eq 1} {
        set ddr_available [lappend ddr_available $x]
      }
    }

    set ddr_ic [tapasco::ip::create_axi_sc "ddr_ic" 2 [llength $ddr_available]]
    tapasco::ip::connect_sc_default_clocks $ddr_ic "host"

    set num_ddr 0
    foreach x $ddr_available {
      puts "Connect AXI master $num_ddr to DDR port $x"
      connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/M0${num_ddr}_AXI"] [get_bd_intf_pins "$f1_inst/S_AXI_DDR${x}"]
      incr num_ddr
    }

    set s_ddr [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DDR"]
    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/S00_AXI"] $s_ddr

    set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_0"]
    connect_bd_intf_net [get_bd_intf_pins "$ddr_ic/S01_AXI"] $s_axi_mem
    # Finished connecting DDR ports

    # Connect "out" AXI ports
    set out_ic [tapasco::ip::create_axi_sc "out_ic" 1 4]
    tapasco::ip::connect_sc_default_clocks $out_ic "design"

    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M00_AXI}] $m_arch
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M01_AXI}] $m_tapasco
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M02_AXI}] $m_dma
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M03_AXI}] $m_intc

    connect_bd_intf_net [get_bd_intf_pins "$out_ic/S00_AXI"] [get_bd_intf_pins "$f1_inst/M_AXI_OCL"]

    # Connect "in" AXI port(s)
    connect_bd_intf_net $s_axi [get_bd_intf_pins "$f1_inst/S_AXI_PCIM"]
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
    return 0x20000;
  }

  proc readfile {filename} {
    set f [open $filename]
    set data [read $f]
    close $f
    return $data
  }

  proc create_f1_shell {} {

    puts "Creating AWS F1 Shell ..."

    set_property ip_repo_paths  "[get_property ip_repo_paths [current_project]] \
        [file join $::env(HDK_SHELL_DIR) hlx design ip aws_v1_0]" [current_project]

    update_ip_catalog

      # Create interface ports
    set S_SH [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aws_f1_sh1_rtl:1.0 S_SH ]

    # Create instance: f1_inst, and set properties
    set f1_inst [ create_bd_cell -type ip -vlnv xilinx.com:ip:aws:1.0 f1_inst ]
    set_property -dict [ list \
        CONFIG.AUX_PRESENT {1} \
        CONFIG.BAR1_PRESENT {0} \
        CONFIG.NUM_A_CLOCKS {2} \
        CONFIG.CLOCK_A0_FREQ {125000000} \
        CONFIG.CLOCK_A1_FREQ {62500000} \
        CONFIG.CLOCK_A2_FREQ {187500000} \
        CONFIG.CLOCK_A3_FREQ {250000000} \
        CONFIG.CLOCK_A_RECIPE {0} \
        CONFIG.DEVICE_ID {0xF000} \
        CONFIG.PCIS_PRESENT {0} \
        CONFIG.PCIM_PRESENT {1} \
        CONFIG.DDR_A_PRESENT {0} \
        CONFIG.DDR_B_PRESENT {0} \
        CONFIG.DDR_C_PRESENT {1} \
        CONFIG.DDR_D_PRESENT {0} \
        CONFIG.OCL_PRESENT {1} \
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

    # Connect ILA to M_AXI_OCL / BAR0
    set ila [tapasco::ip::create_system_ila "maxi_ocl_ila"]
    connect_bd_intf_net [get_bd_intf_pins $ila/SLOT_0_AXI] [get_bd_intf_pins $f1_inst/M_AXI_OCL]
    connect_bd_net [get_bd_pins $ila/clk] [get_bd_pins $f1_inst/clk_main_a0_out]
    connect_bd_net [get_bd_pins $ila/resetn] [get_bd_pins $f1_inst/rst_main_n_out]

    # Required for AFI manifest file

    set ::timestamp [exec date +%y_%m_%d-%H%M%S]

    if {[regexp {HDK_VERSION=([0-9.]+)} [readfile ${::env(HDK_DIR)}/hdk_version.txt] match ::hdk_version] eq 0} {
      puts "WARNING: Could not read HDK_VERSION, using default value"
      set ::hdk_version 1.0.0
    }

    set ::clock_recipe_a [get_property CONFIG.CLOCK_A_RECIPE [get_bd_cells $f1_inst]]
    set ::clock_recipe_b [get_property CONFIG.CLOCK_B_RECIPE [get_bd_cells $f1_inst]]
    set ::clock_recipe_c [get_property CONFIG.CLOCK_C_RECIPE [get_bd_cells $f1_inst]]

    set ::device_id [get_property CONFIG.DEVICE_ID [get_bd_cells $f1_inst]]
    set ::vendor_id [get_property CONFIG.VENDOR_ID [get_bd_cells $f1_inst]]
    set ::subsystem_id [get_property CONFIG.SUBSYSTEM_ID [get_bd_cells $f1_inst]]
    set ::subsystem_vendor_id [get_property CONFIG.SUBSYSTEM_VENDOR_ID [get_bd_cells $f1_inst]]

    # TODO read shell version from file instead? ($HDK_SHELL_DIR/shell_version.txt)
    set ::faas_shell_version [get_property CONFIG.SHELL_VERSION [get_bd_cells $f1_inst]]
    set ::shell_version $::faas_shell_version

    puts "timestamp           = ${::timestamp}"
    puts "hdk_version         = ${::hdk_version}"
    puts "clock_recipe_a      = ${::clock_recipe_a}"
    puts "clock_recipe_b      = ${::clock_recipe_b}"
    puts "clock_recipe_c      = ${::clock_recipe_c}"
    puts "device_id           = ${::device_id}"
    puts "vendor_id           = ${::vendor_id}"
    puts "subsystem_id        = ${::subsystem_id}"
    puts "subsystem_vendor_id = ${::subsystem_vendor_id}"
    puts "shell_version       = ${::shell_version}"

    set ::env(timestamp) $::timestamp
    set ::env(hdk_version) $::hdk_version

    set ::env(CLOCK_A_RECIPE) $::clock_recipe_a
    set ::env(CLOCK_B_RECIPE) $::clock_recipe_b
    set ::env(CLOCK_C_RECIPE) $::clock_recipe_c

    set ::env(device_id) $::device_id
    set ::env(vendor_id) $::vendor_id
    set ::env(subsystem_id) $::subsystem_id
    set ::env(subsystem_vendor_id) $::subsystem_vendor_id

    set ::env(FAAS_SHELL_VERSION) $::faas_shell_version

    create_constraints

    return $f1_inst
  }

  proc create_constraints {} {
    variable platform_dirname

    # TODO this needs to be generated depending on the actual clock settings!
    set constraints_fn [file join $::env(TAPASCO_HOME) platform $platform_dirname constraints cl_clocks_aws.xdc]

    add_files -fileset constrs_1 -norecurse $constraints_fn -force

    set_property PROCESSING_ORDER EARLY [get_files */cl_clocks_aws.xdc]
    set_property USED_IN {synthesis out_of_context implementation} [get_files */cl_clocks_aws.xdc]


    # This contains the CL specific constraints for synthesis at the CL level
    set constraints_fn [file join $::env(HDK_SHELL_DIR) new_cl_template build constraints cl_synth_user.xdc]
    import_files -fileset constrs_1 -force $constraints_fn

    # This contains the CL specific constraints for Top level PNR
    set constraints_fn [file join $::env(HDK_SHELL_DIR) new_cl_template build constraints cl_pnr_user.xdc]
    import_files -fileset constrs_1 -force $constraints_fn
    set_property PROCESSING_ORDER LATE [get_files */cl_pnr_user.xdc]
    set_property USED_IN {implementation} [get_files */cl_pnr_user.xdc]

    set_property is_enabled false [get_files */cl_pnr_user.xdc]
    set ::env(PNR_USER) [get_files */cl_pnr_user.xdc]

    # Add top module (TODO move somewhere else...)
    add_files -norecurse [file join $::env(HDK_SHELL_DIR) hlx design lib cl_top.sv]
  }

  proc generate_wrapper {} {
    puts "Wrapper already added."
  }

  # Begin plugins

  namespace eval aws_plugins {

    proc set_params {args} {
      tapasco::add_capabilities_flag "PLATFORM_CAP0_AWS_EC2_PLATFORM"

      set_msg_config -id {Opt 31-430}       -suppress
      set_msg_config -string {AXI_QUAD_SPI} -suppress

      #set_param hd.clockRoutingWireReduction false
      set_param hd.supportClockNetCrossDiffReconfigurablePartitions 1
      set_param physynth.ultraRAMOptOutput false
      set_param synth.elaboration.rodinMoreOptions {rt::set_parameter disableOregPackingUram true}

      # Create directories for output files

      set ::FAAS_CL_DIR [get_property DIRECTORY [current_project]]
      set ::env(FAAS_CL_DIR) $::FAAS_CL_DIR

      file mkdir "${::FAAS_CL_DIR}/build/checkpoints/to_aws"
      file mkdir "${::FAAS_CL_DIR}/build/reports"

      puts "FAAS_CL_DIR = ${::FAAS_CL_DIR}"

      set platform_dirname $::platform::platform_dirname

      # set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs [current_run -implementation]]
      # set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs [current_run -implementation]]
      # set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs [current_run -implementation]]

      # Set TCL pre/post hooks

      set_property -name "STEPS.OPT_DESIGN.TCL.PRE" \
        -value [file normalize [file join $::env(TAPASCO_HOME) platform $platform_dirname opt_design_pre.tcl]] \
        -objects [get_runs [current_run -implementation]]

      set_property -name "STEPS.OPT_DESIGN.TCL.POST" \
        -value [file normalize [file join $::env(TAPASCO_HOME) platform $platform_dirname opt_design_post.tcl]] \
        -objects [get_runs [current_run -implementation]]

      set_property -name "STEPS.ROUTE_DESIGN.TCL.POST" \
        -value [file normalize [file join $::env(TAPASCO_HOME) platform $platform_dirname route_design_post.tcl]] \
        -objects [get_runs [current_run -implementation]]

      set_property -name "STEPS.PLACE_DESIGN.TCL.POST" \
        -value [file normalize [file join $::env(TAPASCO_HOME) platform $platform_dirname place_design_post.tcl]] \
        -objects [get_runs [current_run -implementation]]

      return $args
    }

    # Before synthesis
    proc pre_synth {args} {
      #set_param sta.enableAutoGenClkNamePersistence 0

      set synth_run [get_runs synth_1]
      set_property -dict [list \
        {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} {-mode out_of_context -max_uram_cascade_height 1} \
        STEPS.SYNTH_DESIGN.ARGS.RETIMING true \
      ] $synth_run

      # STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt \
      # STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE RuntimeOptimized \

      return $args
    }

    proc post_synth {args} {
      set sdp_script_dir [file join $::env(HDK_SHELL_DIR) hlx build scripts subscripts]
      set synth_directory [get_property DIRECTORY [current_run -synthesis]]
      set BD_PATH [get_files */cl.bd]
      set AWS_XDC_PATH NONE
      set _post_synth_dcp "${::FAAS_CL_DIR}/build/checkpoints/CL.post_synth.dcp"

      set const_dir [file normalize [file join ${::FAAS_CL_DIR} build constraints]]
      file mkdir $const_dir
      file copy -force [file normalize [file join $sdp_script_dir cl_debug_bridge_hlx.xdc ]] \
        [file normalize [file join $const_dir cl_debug_bridge_hlx.xdc]]

      puts "*******************************************************"
      puts "sdp_script_dir  = $sdp_script_dir"
      puts "synth_directory = $synth_directory"
      puts "BD_PATH         = $BD_PATH"
      puts "AWS_XDC_PATH    = $AWS_XDC_PATH"
      puts "_post_synth_dcp = $_post_synth_dcp"

      set vivcmd "vivado -mode batch -source [file normalize [file join $sdp_script_dir make_post_synth_dcp.tcl ]] -tclargs\
        -TOP [get_property top [current_fileset]]\
        -IP_REPO [get_property IP_OUTPUT_REPO [get_project [get_projects]]]\
        -SYNTH_DIR $synth_directory\
        -BD_PATH ${BD_PATH}\
        -XDC [get_files */cl_clocks_aws.xdc]\
        -USR_XDC [get_files */cl_synth_user.xdc]\
        -AWS_XDC ${AWS_XDC_PATH}\
        -LINK_DCP_PATH $_post_synth_dcp"

      puts "Create post synth DCP:\n\t$vivcmd"
      exec {*}${vivcmd}
      puts "Finished!"
      puts "*******************************************************"
      puts "\n\n"
    }

    proc create_tarfile {} {
      puts "\nwrite_bitstream disabled, creating tarfile instead..."

      # Lock the design to preserve the placement and routing
      puts "Locking design"
      lock_design -level routing

      report_timing_summary -file $::FAAS_CL_DIR/build/reports/${::timestamp}.SH_CL_final_timing_summary.rpt

      set to_aws_dir "${::FAAS_CL_DIR}/build/checkpoints/to_aws"
      puts "to_aws_dir = ${to_aws_dir}"

      puts "Writing final DCP to to_aws directory"
      write_checkpoint -force ${to_aws_dir}/${::timestamp}.SH_CL_routed.dcp -encrypt

      puts "Write manifest file"
      set manifest_file [open "${to_aws_dir}/${::timestamp}.manifest.txt" w]

      puts "Getting hash"
      set hash [lindex [split [exec sha256sum ${to_aws_dir}/${::timestamp}.SH_CL_routed.dcp] ] 0]

      set vivado_version [string range [version -short] 0 5]
      puts "vivado_version is $vivado_version\n"

      puts $manifest_file "manifest_format_version=2\n"
      puts $manifest_file "pci_vendor_id=${::vendor_id}\n"
      puts $manifest_file "pci_device_id=${::device_id}\n"
      puts $manifest_file "pci_subsystem_id=${::subsystem_id}\n"
      puts $manifest_file "pci_subsystem_vendor_id=${::subsystem_vendor_id}\n"
      puts $manifest_file "dcp_hash=${hash}\n"
      puts $manifest_file "shell_version=${::shell_version}\n"
      puts $manifest_file "tool_version=v${vivado_version}\n"
      puts $manifest_file "dcp_file_name=${::timestamp}.SH_CL_routed.dcp\n"
      puts $manifest_file "hdk_version=${::hdk_version}\n"
      puts $manifest_file "date=${::timestamp}\n"
      puts $manifest_file "clock_recipe_a=A${::clock_recipe_a}\n"
      puts $manifest_file "clock_recipe_b=B${::clock_recipe_b}\n"
      puts $manifest_file "clock_recipe_c=C${::clock_recipe_c}\n"

      close $manifest_file

      package require tar

      set tarfilepath [file normalize [file join $::FAAS_CL_DIR .. "${::timestamp}.${::bitstreamname}.tar"]]

      # Add checkpoint and manifest to tar file from which the AFI can be generated
      # (tar file must contains "to_aws" folder, so change directory accordingly)
      set old_pwd [pwd]
      cd [file normalize [file join $to_aws_dir ..]]
      tar::create $tarfilepath [glob to_aws/${::timestamp}*]
      cd $old_pwd

      puts "\n\nFinished creating tarfile:"
      puts "$tarfilepath\n\n"
    }
  }

  # End plugins

  # Register plugins
  tapasco::register_plugin "platform::aws_plugins::set_params" "pre-arch"
  tapasco::register_plugin "platform::aws_plugins::pre_synth" "pre-synth"
  tapasco::register_plugin "platform::aws_plugins::post_synth" "post-synth"
  tapasco::register_plugin "platform::aws_plugins::create_tarfile" "post-impl"

}

# vim: set expandtab ts=2 sw=2:
