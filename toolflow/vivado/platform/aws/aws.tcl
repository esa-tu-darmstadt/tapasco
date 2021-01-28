# Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
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

namespace eval platform {

  set platform_dirname "aws"

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

  # begin mandatory functions
  proc max_masters {} {
    return [list [::tapasco::get_platform_num_slots]]
  }

  proc number_of_interrupt_controllers {} {
    return 1
  }

  proc get_platform_base_address {} {
    return 0
  }

  proc get_pe_base_address {} {
    return 0x20000
  }
  # end mandatory functions

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
        "M_DMA"      { foreach {base stride range comp} [list 0x00004000 0x2000  0      "PLATFORM_COMPONENT_DMA0"] {} }
        "M_INTC"     { foreach {base stride range comp} [list 0x00010000 0x2000  0      "PLATFORM_COMPONENT_INTC0"] {} }
        "M_MSIX"     { foreach {base stride range comp} [list 0          0       $max64 "PLATFORM_COMPONENT_MSIX0"] {} }
        "M_TAPASCO"  { foreach {base stride range comp} [list 0x00000000 0       0      "PLATFORM_COMPONENT_STATUS"] {} }
        "M_MEM_GPIO" { foreach {base stride range comp} [list 0x00002000 0       0      "PLATFORM_COMPONENT_MEM_GPIO"] {} }
        "M_HOST"     { foreach {base stride range comp} [list 0          0       $max64 ""] {} }
        "M_MEM_0"    { foreach {base stride range comp} [list 0          0       $max64 ""] {} }
        "M_ARCH"     { set base "skip" }
        "M_DDR"      { foreach {base stride range comp} [list 0 0 0 ""] {} }
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

  proc create_subsystem_intc {} {

    set s_axi [create_bd_intf_pin -mode Slave -vlnv [tapasco::ip::get_vlnv "aximm_intf"] "S_INTC"]
    set aclk [tapasco::subsystem::get_port "host" "clk"]
    set p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set ic_aresetn [::tapasco::subsystem::get_port "host" "rst" "interconnect"]

    # using type "undef" instead of "intr" to be compatible with F1 shell
    set irq_output [create_bd_pin -from 15 -to 0 -type "undef" -dir O "interrupts"]
    set ack_input [create_bd_pin -from 15 -to 0 -type "undef" -dir I "interrupts_ack"]

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

    # Interrupt Controller
    set intr_ctrl [tapasco::ip::create_aws_intr_ctrl "aws_intr_ctrl"]

    connect_bd_net [get_bd_pins ${design_concats_last}/dout] [get_bd_pins $intr_ctrl/interrupt_design] 
    connect_bd_net [get_bd_pins ${host_concat}/dout] [get_bd_pins $intr_ctrl/interrupt_pcie]

    # connect internal clocks
    connect_bd_net $aclk [get_bd_pins -of_objects $intr_ctrl -filter {NAME == "S_AXI_ACLK"}]
    connect_bd_net $design_aclk [get_bd_pins -of_objects $intr_ctrl -filter {NAME == "design_clk"}]
    connect_bd_net $p_aresetn [get_bd_pins -of_objects $intr_ctrl -filter {NAME == "S_AXI_ARESETN"}]
    connect_bd_net $design_aresetn [get_bd_pins -of_objects $intr_ctrl -filter {NAME == "design_rst"}]

    # connect S_AXI
    connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $intr_ctrl -filter {NAME == "S_AXI"}]

    connect_bd_net [get_bd_pins -of_object $intr_ctrl -filter {NAME == "irq_req"}] $irq_output
    connect_bd_net $ack_input [get_bd_pins -of_object $intr_ctrl -filter {NAME == "irq_ack"}]
  }

  # Creates the memory subsystem
  proc create_subsystem_memory {} {
    set m_axi_mem [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_HOST"]
    set s_axi_ddma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA"]
    set s_axi_gpio [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_GPIO"]

    set pcie_aclk [tapasco::subsystem::get_port "host" "clk"]

    set pcie_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]

    set ddr_ready [create_bd_pin -type "undef" -dir "I" "ddr_ready"]

    set gpio [tapasco::ip::create_axi_gpio "axi_gpio"]
    set_property -dict [list \
      {CONFIG.C_GPIO_WIDTH} {4} \
      {CONFIG.C_ALL_INPUTS} {1}
    ] $gpio
    connect_bd_net $ddr_ready [get_bd_pins -of_objects $gpio -filter {NAME == "gpio_io_i"}]
    connect_bd_intf_net $s_axi_gpio [get_bd_intf_pins -of_objects $gpio -filter {NAME == "S_AXI"}]

    connect_bd_net \
      [get_bd_pins -of_objects $gpio -filter {NAME == "s_axi_aclk"}] \
      [tapasco::subsystem::get_port "host" "clk"]

    connect_bd_net \
      [get_bd_pins -of_objects $gpio -filter {NAME == "s_axi_aresetn"}] \
      [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]

    set dma [tapasco::ip::create_bluedma_x16 "dma"]
    connect_bd_net [get_bd_pins -of_objects $dma -filter {NAME == "IRQ_read"}] [::tapasco::ip::add_interrupt "PLATFORM_COMPONENT_DMA0_READ" "host"]
    connect_bd_net [get_bd_pins -of_objects $dma -filter {NAME == "IRQ_write"}] [::tapasco::ip::add_interrupt "PLATFORM_COMPONENT_DMA0_WRITE" "host"]

    # connect DMA 64bit to external port
    connect_bd_intf_net [get_bd_intf_pins -of_objects $dma -filter {NAME == "m64_axi"}] $m_axi_mem

    # connect DMA S_AXI to external port
    connect_bd_intf_net $s_axi_ddma [get_bd_intf_pins -of_objects $dma -filter {NAME == "S_AXI"}]

    # create port for access to DDR memory
    set m_ddr [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DDR"]

    connect_bd_intf_net $m_ddr [get_bd_intf_pins -of_objects $dma -filter {NAME == "m32_axi"}]

    # connect PCIe clock and reset
    connect_bd_net $pcie_aclk [get_bd_pins -of_objects $dma -filter {NAME =~ "*_axi_aclk"}]
    connect_bd_net $pcie_p_aresetn [get_bd_pins -of_objects $dma -filter {NAME =~ "*_axi_aresetn"}]
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
    set m_mem_gpio [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_MEM_GPIO"]
    set pcie_aclk [create_bd_pin -type "clk" -dir "O" "pcie_aclk"]
    set pcie_aresetn [create_bd_pin -type "rst" -dir "O" "pcie_aresetn"]

    # using type "undef" instead of "intr" to be compatible with F1 shell
    set irq_input [create_bd_pin -type "undef" -dir I "interrupts"]
    set ack_output [create_bd_pin -type "undef" -dir O "interrupts_ack"]

    # create instances of shell
    set f1_inst [create_f1_shell]

    set oldCurInst [current_bd_instance .]
    current_bd_instance "/arch"
    set arch_axi_m [get_bd_intf_pins -filter {VLNV == "xilinx.com:interface:aximm_rtl:1.0" && MODE == "Master"}]
    current_bd_instance $oldCurInst

    connect_bd_net $irq_input [get_bd_pins -of_objects $f1_inst -filter {NAME == "irq_req"}]
    connect_bd_net $ack_output [get_bd_pins -of_objects $f1_inst -filter {NAME == "irq_ack"}]

    # For some design clock frequencies, the MMCM can be omitted by using a
    # clock output of the Shell. There are three clock groups (A, B, C) with
    # up to 4 outputs:
    #     0   1   2   3
    # A: 250 125 375 500
    # B: 450 225
    # C: 150 200
    switch [tapasco::get_design_frequency] {
      "250" {
          set clk_group "a"
          set clk_port "0"
      }
      "125" {
          set clk_group "a"
          set clk_port "1"
      }
      "375" {
          set clk_group "a"
          set clk_port "2"
      }
      "500" {
          set clk_group "a"
          set clk_port "3"
      }
      "450" {
          set clk_group "b"
          set clk_port "0"
      }
      "225" {
          set clk_group "b"
          set clk_port "1"
      }
      "150" {
          set clk_group "c"
          set clk_port "0"
      }
      "200" {
          set clk_group "c"
          set clk_port "1"
      }
    }

    set clkwiz_design_aclk [create_bd_pin -type "clk" -dir "O" "design_aclk"]
    set clkwiz_design_aresetn [create_bd_pin -type "rst" -dir "O" "design_aresetn"]

    if {[info exist clk_group] eq 0} {
      set design_clk_wiz [tapasco::ip::create_clk_wiz design_clk_wiz]
      set_property -dict [list \
        {CONFIG.CLK_OUT1_PORT} {design_clk} \
        {CONFIG.USE_SAFE_CLOCK_STARTUP} {false} \
        {CONFIG.CLKOUT1_REQUESTED_OUT_FREQ} [tapasco::get_design_frequency] \
        {CONFIG.USE_LOCKED} {true} \
        {CONFIG.USE_RESET} {true} \
        {CONFIG.RESET_TYPE} {ACTIVE_LOW} \
        {CONFIG.RESET_PORT} {resetn} \
      ] $design_clk_wiz

      connect_bd_net \
        [get_bd_pins -of_objects $design_clk_wiz -filter {NAME == "resetn"}] \
        [get_bd_pins -of_objects $f1_inst -filter {NAME == "rst_main_n_out"}]
      connect_bd_net \
        [get_bd_pins -of_objects $design_clk_wiz -filter {NAME == "clk_in1"}] \
        [get_bd_pins -of_objects $f1_inst -filter {NAME == "clk_extra_a1_out"}]

      # connect external design clk
      connect_bd_net [get_bd_pins -of_objects $design_clk_wiz -filter {NAME == "design_clk"}] $clkwiz_design_aclk
      connect_bd_net [get_bd_pins -of_objects $design_clk_wiz -filter {NAME == "locked"}] $clkwiz_design_aresetn
    } else {
      set_property -dict [list \
        "CONFIG.NUM_[string toupper $clk_group]_CLOCKS" [expr "$clk_port + 1"] \
        {CONFIG.CLOCK_B_RECIPE} {2} \
        {CONFIG.CLOCK_C_RECIPE} {1} \
      ] $f1_inst

      if {$clk_group == "a" && $clk_port == "0"} {
        connect_bd_net [get_bd_pins -of_objects $f1_inst -filter {NAME == "clk_main_a0_out"}] $clkwiz_design_aclk
      } else {
        connect_bd_net \
          [get_bd_pins -of_objects $f1_inst -filter "NAME == clk_extra_${clk_group}${clk_port}_out"] \
          $clkwiz_design_aclk
      }
      connect_bd_net [get_bd_pins -of_objects $f1_inst -filter {NAME == "rst_main_n_out"}] $clkwiz_design_aresetn
    }

    # DDR training status
    set ddr_ready [create_bd_pin -type "undef" -dir O "ddr_ready"]
    set ddr_concat [tapasco::ip::create_xlconcat "ddr_ready_concat" 4]
    connect_bd_net [get_bd_pins -of_objects $ddr_concat -filter {NAME == "dout"}] $ddr_ready

    # Connect DDR ports (DDR C is inside the Shell and should always be available)
    set ddr_available {}
    set i 0
    foreach x {A B C D} {
      if {[get_property "CONFIG.DDR_${x}_PRESENT" $f1_inst] eq 1} {
        set ddr_available [lappend ddr_available $x]
        connect_bd_net \
          [get_bd_pins -of_objects $f1_inst -filter "NAME == ddr[string tolower $x]_is_ready"] \
          [get_bd_pins -of_objects $ddr_concat -filter "NAME == In${i}"]
      }
      incr i
    }

    # Connect DMA engine and architecture to local memory

    # To use a SmartConnect, uncomment the following code and comment the code after this block

    # set ddr_ic [tapasco::ip::create_axi_sc "ddr_ic" [expr "1 + [llength $arch_axi_m]"] [llength $ddr_available]]
    # set_property -dict [list CONFIG.NUM_CLKS {2}] $ddr_ic
    # connect_bd_net [tapasco::subsystem::get_port "design" "clk"] [get_bd_pins $ddr_ic/aclk1]
    # connect_bd_net [tapasco::subsystem::get_port "host" "clk"] [get_bd_pins $ddr_ic/aclk]

    set ddr_ic [tapasco::ip::create_axi_ic "ddr_ic" 2 [llength $ddr_available]]

    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME == "ACLK"}] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME =~ S00_* && TYPE == clk}] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME =~ M* && TYPE == clk}]

    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME =~ S01_* && TYPE == clk}]

    connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME == "ARESETN"}] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME =~ S00* && TYPE == rst}] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME =~ M* && TYPE == rst}]

    connect_bd_net [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"] \
      [get_bd_pins -of_objects $ddr_ic -filter {NAME =~ S01_* && TYPE == rst}]

    set num_ddr 0
    foreach x $ddr_available {
      puts "Connect AXI master $num_ddr to DDR port $x"
      connect_bd_intf_net \
        [get_bd_intf_pins -of_objects $ddr_ic -filter "NAME == M0${num_ddr}_AXI"] \
        [get_bd_intf_pins -of_objects $f1_inst -filter "NAME == S_AXI_DDR${x}"]
      incr num_ddr
    }

    set s_ddr [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DDR"]
    connect_bd_intf_net [get_bd_intf_pins -of_objects $ddr_ic -filter {NAME == "S00_AXI"}] $s_ddr

    for {set i 0} {$i < [llength $arch_axi_m]} {incr i} {
      set s_axi_mem [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 [format "S_MEM_%d" $i]]
      connect_bd_intf_net [get_bd_intf_pins [format "$ddr_ic/S%02d_AXI" [expr "$i + 1"]]] $s_axi_mem
    }

    # Connect configuration AXI ports (connected to 32 MB BAR provided by the Shell)

    # To use a SmartConnect, uncomment the following code and comment the code after this block

    # set out_ic [tapasco::ip::create_axi_sc "out_ic" 1 4]
    # tapasco::ip::connect_sc_default_clocks $out_ic "design"

    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M00_AXI}] $m_arch
    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M01_AXI}] $m_tapasco
    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M02_AXI}] $m_dma
    # connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M03_AXI}] $m_intc

    # connect_bd_intf_net [get_bd_intf_pins "$out_ic/S00_AXI"] [get_bd_intf_pins "$f1_inst/M_AXI_OCL"]

    set out_ic [tapasco::ip::create_axi_ic "out_ic" 1 5]

    # Without this, Vivado chooses wrong parameters (at least in 2018.3)
    set_property -dict [list \
      {CONFIG.ENABLE_ADVANCED_OPTIONS} {1} \
      {CONFIG.XBAR_DATA_WIDTH} {32} \
    ] $out_ic

    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M00_AXI}] $m_arch
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M01_AXI}] $m_tapasco
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M02_AXI}] $m_dma
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M03_AXI}] $m_intc
    connect_bd_intf_net [get_bd_intf_pins -of_objects $out_ic -filter {NAME == M04_AXI}] $m_mem_gpio

    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] \
      [get_bd_pins -of_objects $out_ic -filter {NAME == ACLK}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ S0* && TYPE == clk}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M01_* && TYPE == clk}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M02_* && TYPE == clk}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M03_* && TYPE == clk}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M04_* && TYPE == clk}]

    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M00_* && TYPE == clk}]

    connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] \
      [get_bd_pins -of_objects $out_ic -filter {NAME == ARESETN}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ S0* && TYPE == rst}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M01_* && TYPE == rst}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M02_* && TYPE == rst}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M03_* && TYPE == rst}] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M04_* && TYPE == rst}]

    connect_bd_net [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"] \
      [get_bd_pins -of_objects $out_ic -filter {NAME =~ M00_* && TYPE == rst}]

    connect_bd_intf_net [get_bd_intf_pins -of_objects $f1_inst -filter {NAME == "M_AXI_OCL"}] \
      [get_bd_intf_pins -of_objects $out_ic -filter {NAME == "S00_AXI"}]

    # Connect "in" AXI ports
    set in_ic [tapasco::ip::create_axi_ic "in_ic" 1 1]

    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] \
      [get_bd_pins -of_objects $in_ic -filter {TYPE == clk}]

    connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] \
      [get_bd_pins -of_objects $in_ic -filter {TYPE == rst}]

    connect_bd_intf_net [get_bd_intf_pins S_HOST] \
      [get_bd_intf_pins -of_objects $in_ic -filter {NAME == S00_AXI}]
    connect_bd_intf_net [get_bd_intf_pins -of_object $in_ic -filter { MODE == Master }] \
      [get_bd_intf_pins -of_objects $f1_inst -filter {NAME == "S_AXI_PCIM"}]
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
    connect_bd_net $pcie_clk [get_bd_pins -of_objects $host_rst_gen -filter {NAME == "slowest_sync_clk"}] \
      [tapasco::subsystem::get_port "host" "clk"]
    connect_bd_net $pcie_aresetn [get_bd_pins -of_objects $host_rst_gen -filter {NAME == "ext_reset_in"}]

    connect_bd_net $ddr_clk [get_bd_pins -of_objects $mem_rst_gen -filter {NAME == "slowest_sync_clk"}] \
      [tapasco::subsystem::get_port "mem" "clk"]
    connect_bd_net $ddr_clk_aresetn [get_bd_pins -of_objects $mem_rst_gen -filter {NAME == "ext_reset_in"}]

    connect_bd_net $design_clk [get_bd_pins -of_objects $design_rst_gen -filter {NAME == "slowest_sync_clk"}] \
      [tapasco::subsystem::get_port "design" "clk"]
    connect_bd_net $design_clk_aresetn [get_bd_pins -of_objects $design_rst_gen -filter {NAME == "ext_reset_in"}]

    # connect to clock reset master
    connect_bd_net [get_bd_pins -of_objects $host_rst_gen -filter {NAME == "peripheral_aresetn"}] \
      [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]

    connect_bd_net [get_bd_pins -of_objects $host_rst_gen -filter {NAME == "peripheral_reset"}] \
      [tapasco::subsystem::get_port "host" "rst" "peripheral" "reset"]

    connect_bd_net [get_bd_pins -of_objects $host_rst_gen -filter {NAME == "interconnect_aresetn"}] \
      [tapasco::subsystem::get_port "host" "rst" "interconnect"]


    connect_bd_net [get_bd_pins -of_objects $design_rst_gen -filter {NAME == "peripheral_aresetn"}] \
      [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    connect_bd_net [get_bd_pins -of_objects $design_rst_gen -filter {NAME == "peripheral_reset"}] \
      [tapasco::subsystem::get_port "design" "rst" "peripheral" "reset"]

    connect_bd_net [get_bd_pins -of_objects $design_rst_gen -filter {NAME == "interconnect_aresetn"}] \
      [tapasco::subsystem::get_port "design" "rst" "interconnect"]


    connect_bd_net [get_bd_pins -of_objects $mem_rst_gen -filter {NAME == "peripheral_aresetn"}] \
      [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]

    connect_bd_net [get_bd_pins -of_objects $mem_rst_gen -filter {NAME == "peripheral_reset"}] \
      [tapasco::subsystem::get_port "mem" "rst" "peripheral" "reset"]

    connect_bd_net [get_bd_pins -of_objects $mem_rst_gen -filter {NAME == "interconnect_aresetn"}] \
      [tapasco::subsystem::get_port "mem" "rst" "interconnect"]
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
    set_property -dict [list \
      {CONFIG.AUX_PRESENT} {1} \
      {CONFIG.BAR1_PRESENT} {0} \
      {CONFIG.NUM_A_CLOCKS} {2} \
      {CONFIG.CLOCK_A_RECIPE} {1} \
      {CONFIG.DEVICE_ID} {0xF000} \
      {CONFIG.PCIS_PRESENT} {0} \
      {CONFIG.PCIM_PRESENT} {1} \
      {CONFIG.DDR_A_PRESENT} {1} \
      {CONFIG.DDR_B_PRESENT} {1} \
      {CONFIG.DDR_C_PRESENT} {1} \
      {CONFIG.DDR_D_PRESENT} {1} \
      {CONFIG.OCL_PRESENT} {1} \
      {CONFIG.SDA_PRESENT} {0} \
    ] $f1_inst

    set ddr_aclk [create_bd_pin -type "clk" -dir "O" "ddr_aclk"]
    set ddr_aresetn [create_bd_pin -type "rst" -dir "O" "ddr_aresetn"]

    # Connect S_SH pin
    set oldCurInst [current_bd_instance .]
    current_bd_instance
    connect_bd_intf_net $S_SH [get_bd_intf_pins -of_objects $f1_inst -filter {NAME == "S_SH"}]
    current_bd_instance $oldCurInst

    connect_bd_net [get_bd_pins "pcie_aclk"] \
      [get_bd_pins -of_objects $f1_inst -filter {NAME == "clk_main_a0_out"}]
    connect_bd_net [get_bd_pins "pcie_aresetn"] \
      [get_bd_pins -of_objects $f1_inst -filter {NAME == "rst_main_n_out"}]

    connect_bd_net $ddr_aclk \
      [get_bd_pins -of_objects $f1_inst -filter {NAME == "clk_main_a0_out"}]
    connect_bd_net $ddr_aresetn \
      [get_bd_pins -of_objects $f1_inst -filter {NAME == "rst_main_n_out"}]

    set ::timestamp [exec date +%y_%m_%d-%H%M%S]

    if {[regexp {HDK_VERSION=([0-9.]+)} [readfile ${::env(HDK_DIR)}/hdk_version.txt] match ::hdk_version] eq 0} {
      puts "WARNING: Could not read HDK_VERSION, using default value"
      set ::hdk_version 1.0.0
    }

    set ::clock_recipe_a "1"
    set ::clock_recipe_b "2"
    set ::clock_recipe_c "1"

    set ::device_id [get_property CONFIG.DEVICE_ID [get_bd_cells $f1_inst]]
    set ::vendor_id [get_property CONFIG.VENDOR_ID [get_bd_cells $f1_inst]]
    set ::subsystem_id [get_property CONFIG.SUBSYSTEM_ID [get_bd_cells $f1_inst]]
    set ::subsystem_vendor_id [get_property CONFIG.SUBSYSTEM_VENDOR_ID [get_bd_cells $f1_inst]]

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

    set constraints_fn [file join $::env(TAPASCO_HOME_TCL) platform $platform_dirname constraints 250 cl_clocks_aws.xdc]

    add_files -fileset constrs_1 -norecurse $constraints_fn -force

    set_property PROCESSING_ORDER EARLY [get_files */cl_clocks_aws.xdc]
    set_property USED_IN {synthesis out_of_context implementation} [get_files */cl_clocks_aws.xdc]

    # Additional constraints for custom logic (CL) synthesis
    set constraints_fn [file join $::env(HDK_SHELL_DIR) new_cl_template build constraints cl_synth_user.xdc]
    import_files -fileset constrs_1 -force $constraints_fn

    # Additional constraints for top level implementation
    set constraints_fn [file join $::env(HDK_SHELL_DIR) new_cl_template build constraints cl_pnr_user.xdc]
    import_files -fileset constrs_1 -force $constraints_fn

    set_property -dict [list \
      {PROCESSING_ORDER} {LATE} \
      {USED_IN} {implementation} \
      {is_enabled} {false} \
    ] [get_files */cl_pnr_user.xdc]

    set ::env(PNR_USER) [get_files */cl_pnr_user.xdc]
  }

  proc generate_wrapper {} {
    add_files -norecurse [file join $::env(HDK_SHELL_DIR) hlx design lib cl_top.sv]
  }

  # Begin plugins

  namespace eval aws_plugins {

    proc set_params {args} {
      set_msg_config -id {Opt 31-430}       -suppress
      set_msg_config -string {AXI_QUAD_SPI} -suppress

      set_param hd.supportClockNetCrossDiffReconfigurablePartitions 1
      set_param physynth.ultraRAMOptOutput false
      set_param synth.elaboration.rodinMoreOptions {rt::set_parameter disableOregPackingUram true}

      # Create directories for output files
      set ::FAAS_CL_DIR [get_property DIRECTORY [current_project]]
      set ::env(FAAS_CL_DIR) $::FAAS_CL_DIR

      file mkdir [file join ${::FAAS_CL_DIR} build checkpoints to_aws]
      file mkdir [file join ${::FAAS_CL_DIR} build reports]

      set platform_dirname $::platform::platform_dirname
      set impl_run [get_runs [current_run -implementation]]
      set hook_dir [file join $::env(TAPASCO_HOME_TCL) platform $platform_dirname hooks]

      # Set TCL pre/post hooks
      set_property -dict [list \
        {STEPS.OPT_DESIGN.TCL.PRE} [file normalize [file join $hook_dir opt_design_pre.tcl]] \
        {STEPS.OPT_DESIGN.TCL.POST} [file normalize [file join $hook_dir opt_design_post.tcl]] \
        {STEPS.ROUTE_DESIGN.TCL.POST} [file normalize [file join $hook_dir route_design_post.tcl]] \
      ] $impl_run

      return $args
    }

    # Before synthesis
    proc pre_synth {args} {
      set synth_run [get_runs synth_1]
      set_property -dict [list \
        {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} {-mode out_of_context -max_uram_cascade_height 1} \
        {STEPS.SYNTH_DESIGN.ARGS.RETIMING} {true} \
      ] $synth_run

      # Work around an obscure bug that sometimes crashes Vivado
      validate_bd_design -force

      return $args
    }

    proc post_synth {args} {
      set script_dir [file join $::env(HDK_SHELL_DIR) hlx build scripts subscripts]

      set const_dir [file normalize [file join ${::FAAS_CL_DIR} build constraints]]
      file mkdir $const_dir

      file copy -force [file normalize [file join $script_dir cl_debug_bridge_hlx.xdc]] \
        [file normalize [file join $const_dir cl_debug_bridge_hlx.xdc]]

      set vivado_cmd "vivado -mode batch -source [file normalize [file join $script_dir make_post_synth_dcp.tcl]] -tclargs\
        -TOP [get_property top [current_fileset]]\
        -IP_REPO [get_property IP_OUTPUT_REPO [get_project [get_projects]]]\
        -SYNTH_DIR [get_property DIRECTORY [current_run -synthesis]]\
        -BD_PATH [get_files */cl.bd]\
        -XDC [get_files */cl_clocks_aws.xdc]\
        -USR_XDC [get_files */cl_synth_user.xdc]\
        -AWS_XDC NONE\
        -LINK_DCP_PATH [file join ${::FAAS_CL_DIR} build checkpoints CL.post_synth.dcp]"

      puts "Create post synth DCP:\n\t${vivado_cmd}"
      exec {*}${vivado_cmd}
      puts "Finished!\n\n"
    }

    proc create_tarfile {} {
      puts "\nwrite_bitstream disabled, creating tarfile instead..."

      puts "Locking design..."
      lock_design -level routing

      set to_aws_dir [file join ${::FAAS_CL_DIR} build checkpoints to_aws]

      puts "Writing final encrypted DCP..."
      set final_dcp [file join ${to_aws_dir} "${::timestamp}.SH_CL_routed.dcp"]
      write_checkpoint -force $final_dcp -encrypt

      puts "Writing manifest file..."

      set dcp_hash [lindex [split [exec sha256sum $final_dcp]] 0]
      set tool_version [string range [version -short] 0 5]

      # Reference: https://github.com/aws/aws-fpga/blob/master/hdk/docs/AFI_Manifest.md
      set manifest [open [file join ${to_aws_dir} "${::timestamp}.manifest.txt"] w]
      puts $manifest [join [list\
        "manifest_format_version=2"\
        "pci_vendor_id=${::vendor_id}"\
        "pci_device_id=${::device_id}"\
        "pci_subsystem_id=${::subsystem_id}"\
        "pci_subsystem_vendor_id=${::subsystem_vendor_id}"\
        "dcp_hash=${dcp_hash}"\
        "shell_version=${::shell_version}"\
        "tool_version=v${tool_version}"\
        "dcp_file_name=${::timestamp}.SH_CL_routed.dcp"\
        "hdk_version=${::hdk_version}"\
        "date=${::timestamp}"\
        "clock_recipe_a=A${::clock_recipe_a}"\
        "clock_recipe_b=B${::clock_recipe_b}"\
        "clock_recipe_c=C${::clock_recipe_c}"\
      ] "\n"]
      close $manifest

      package require tar

      set tarfilepath [file normalize [file join $::FAAS_CL_DIR .. "${::bitstreamname}.tar"]]

      # Add checkpoint and manifest to tar file from which the AFI can be generated
      # (tar file must contain "to_aws" folder, so change directory accordingly)
      set old_pwd [pwd]
      cd [file normalize [file join $to_aws_dir ..]]
      tar::create $tarfilepath [glob to_aws/${::timestamp}*]
      cd $old_pwd

      puts "\n\nFinished creating tarfile:"
      puts "$tarfilepath\n\n"
    }

    proc check_hdk {} {
      if {[info exist ::env(HDK_SHELL_DIR)] eq 0} {
        puts "****************************************************************"
        puts "* Environment variable HDK_SHELL_DIR is not set.               *"
        puts "* This likely means the F1 HDK has not been (properly) set up. *"
        puts "* Please download/clone the current version from:              *"
        puts "* https://github.com/aws/aws-fpga                              *"
        puts "* Before using TaPaSCo, run 'source hdk_setup.sh'.             *"
        puts "****************************************************************"
        exit 1
      }
    }

    proc post_addr_map {} {
      # Debug failed address mapping
      save_bd_design

      # Dummy component which can be used to identify the F1 platform
      ::platform::addressmap::add_platform_component "PLATFORM_COMPONENT_AWS_EC2" 0 0
    }
  }
  # End plugins

  # Register plugins
  tapasco::register_plugin "platform::aws_plugins::check_hdk" "post-init"
  tapasco::register_plugin "platform::aws_plugins::set_params" "pre-arch"
  tapasco::register_plugin "platform::aws_plugins::pre_synth" "pre-synth"
  tapasco::register_plugin "platform::aws_plugins::post_synth" "post-synth"
  tapasco::register_plugin "platform::aws_plugins::create_tarfile" "post-impl"
  tapasco::register_plugin "platform::aws_plugins::post_addr_map" "post-address-map"

}

# vim: set expandtab ts=2 sw=2:
