#
# Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
#
# This file is part of Tapasco (TaPaSCo).
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
# @file		zynq.tcl
# @brief	Zynq-7000 platform implementation: For simulation, there is an extra AXI
#               master connected to HP3 (to simulate loading of data). Up to 16 instances
#               of AXI Interrupt Controllers are instantiated, depending on the number
#               interrupt sources returned by the architecture.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
#
source -notrace $::env(TAPASCO_HOME)/platform/common/platform.tcl

namespace eval ::platform {
  namespace export max_masters
  namespace export get_address_map

  # check if TAPASCO_HOME env var is set
  if {![info exists ::env(TAPASCO_HOME)]} {
    puts "Could not find TaPaSCo root directory, please set environment variable 'TAPASCO_HOME'."
    exit 1
  }
  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/zynq/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list 64 64]
  }

  proc get_pe_base_address {} {
    return 0x43C00000
  }

  proc get_address_map {{pe_base ""}} {
    set max32 [expr "1 << 32"]
    if {$pe_base == ""} { set pe_base [get_pe_base_address] }
    puts "Computing addresses for PEs ..."
    set peam [::arch::get_address_map $pe_base]
    puts "Computing addresses for masters ..."
    foreach m [::tapasco::get_aximm_interfaces [get_bd_cells -filter "PATH !~ [::tapasco::subsystem::get arch]/*"]] {
      switch -glob [get_property NAME $m] {
        "M_TAPASCO" { foreach {base stride range comp} [list 0x77770000 0       0 "PLATFORM_COMPONENT_STATUS"] {} }
        "M_INTC"    { foreach {base stride range comp} [list 0x81800000 0x10000 0 "PLATFORM_COMPONENT_INTC0"] {} }
        "M_ARCH"    { set base "skip" }
        default     { foreach {base stride range comp} [list 0 0 0 ""] {} }
      }
      if {$base != "skip"} { set peam [addressmap::assign_address $peam $m $base $stride $range $comp] }
    }
    return $peam
  }

  proc number_of_interrupt_controllers {} {
    set no_pes [llength [arch::get_processing_elements]]
    return [expr "$no_pes > 96 ? 4 : ($no_pes > 64 ? 3 : ($no_pes > 32 ? 2 : 1))"]
  }

  # Creates a subsystem with clock and reset generation for a list of clocks.
  # Consists of clocking wizard + reset generators with single ext. reset in.
  # @param freqs list of name frequency (MHz) pairs, e.g., [list design 100 memory 250]
  # @param name Name of the subsystem group
  # @return Subsystem group
  proc create_subsystem_clocks_and_resets {} {
    set freqs [::tapasco::get_frequencies]
    puts "Creating clock and reset subsystem ..."
    puts "  frequencies: $freqs"
    
    set reset_in [create_bd_pin -dir I -type rst "reset_in"]
    set clk_wiz [::tapasco::ip::create_clk_wiz "clk_wiz"]
    set_property -dict [list CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false}] $clk_wiz
    set clk_mode [lindex [get_board_part_interfaces -filter { NAME =~ sys*clock }] 0]

    if {$clk_mode == ""} {
      error "could not find a board interface for the sys clock - check board part?"
    }
    set_property CONFIG.CLK_IN1_BOARD_INTERFACE $clk_mode $clk_wiz

    # check if external port already exists, re-use
    if {[get_bd_ports -quiet "/$clk_mode"] != {}} {
      # connect existing top-level port
      connect_bd_net [get_bd_ports "/$clk_mode"] [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $clk_wiz]
      # use PLL primitive for all but the first subsystem (MMCMs are limited)
      set_property -dict [list CONFIG.PRIMITIVE {PLL} CONFIG.USE_MIN_POWER {true}] $clk_wiz
    } {
      # apply board automation to create top-level port
      if {$clk_mode == "sys_diff_clock"} {
        set cport [get_bd_intf_pins -of_objects $clk_wiz]
      } {
        set cport [get_bd_pins -filter {DIR == I} -of_objects $clk_wiz]
      }
      puts "  clk_wiz: $clk_wiz, cport: $cport"
      if {$cport != {}} {
        # apply board automation
        apply_bd_automation -rule xilinx.com:bd_rule:board -config "Board_Interface $clk_mode" $cport
        puts "board automation worked, moving on"
      } {
        # last resort: try to call platform::create_clock_port
        set clk_mode "sys_clk"
        set cport [platform::create_clock_port $clk_mode]
        connect_bd_net $cport [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $clk_wiz]
      }
    }

    for {set i 0; set clkn 1} {$i < [llength $freqs]} {incr i 2} {
      set name [lindex $freqs $i]
      set freq [lindex $freqs [expr $i + 1]]
      #set clkn [expr "$i / 2 + 1"]
      puts "  instantiating clock: $name @ $freq MHz"
      for {set j 0} {$j < $i} {incr j 2} {
        if {[lindex $freqs [expr $j + 1]] == $freq} {
          puts "    $name is same frequency as [lindex $freqs $j], re-using"
          break
        }
      }
      # get ports
      puts "current name: $name"
      if {$name == "memory"} { set name "mem" }
      set clk    [::tapasco::subsystem::get_port $name "clk"]
      set p_rstn [::tapasco::subsystem::get_port $name "rst" "peripheral" "resetn"]
      set p_rst  [::tapasco::subsystem::get_port $name "rst" "peripheral" "reset"]
      set i_rstn [::tapasco::subsystem::get_port $name "rst" "interconnect"]

      if {[expr "$j < $i"]} {
        # simply re-wire sources
        set rst_gen [get_bd_cells "[lindex $freqs $j]_rst_gen"]
        set ex_clk [::tapasco::subsystem::get_port [lindex $freqs $j] "clk"]
        puts "rst_gen = $rst_gen"
        connect_bd_net -net [get_bd_nets -boundary_type lower -of_objects $ex_clk] $clk
        connect_bd_net [get_bd_pins $rst_gen/peripheral_aresetn] $p_rstn
        connect_bd_net [get_bd_pins $rst_gen/peripheral_reset] $p_rst
        connect_bd_net [get_bd_pins $rst_gen/interconnect_aresetn] $i_rstn
      } {
        set_property -dict [list CONFIG.CLKOUT${clkn}_USED {true} CONFIG.CLKOUT${clkn}_REQUESTED_OUT_FREQ $freq] $clk_wiz
        set clkp [get_bd_pins "$clk_wiz/clk_out${clkn}"]
        set rstgen [::tapasco::ip::create_rst_gen "${name}_rst_gen"]
        connect_bd_net $clkp $clk
        connect_bd_net $reset_in [get_bd_pins "$rstgen/ext_reset_in"]
        connect_bd_net $clkp [get_bd_pins "$rstgen/slowest_sync_clk"]
        connect_bd_net [get_bd_pins "$rstgen/peripheral_reset"] $p_rst
        connect_bd_net [get_bd_pins "$rstgen/peripheral_aresetn"] $p_rstn
        connect_bd_net [get_bd_pins "$rstgen/interconnect_aresetn"] $i_rstn
        incr clkn
      }
    }
  }

  proc create_subsystem_memory {} {
    set mem_slaves  [list]
    set mem_masters [list]
    set arch_masters [::arch::get_masters]
    set ps_slaves [list "HP0" "HP1" "ACP"]
    puts "Creating memory slave ports for [llength $arch_masters] masters ..."
    if {[llength $arch_masters] > [llength $ps_slaves]} {
      error "  trying to connect [llength $arch_masters] architecture masters, " \
        "but only [llength $ps_slaves] memory interfaces are available"
    }
    set m_i 0
    foreach m $arch_masters {
      set name [regsub {^M_(.*)} [get_property NAME $m] {S_\1}]
      puts "  $m -> $name"
      lappend mem_slaves [create_bd_intf_pin -mode Slave -vlnv [get_property VLNV $m] $name]
      lappend mem_masters [create_bd_intf_pin -mode Master -vlnv [::tapasco::ip::get_vlnv "aximm_intf"] "M_[lindex $ps_slaves $m_i]"]
      incr m_i
    }

    if {$m_i == 0} {
      set name [format "S_%s" [lindex $ps_slaves 0]]
      set vlnv [::tapasco::ip::get_vlnv "aximm_intf"]
      lappend mem_slaves [create_bd_intf_pin -mode Slave -vlnv $vlnv $name]
      lappend mem_masters [create_bd_intf_pin -mode Master -vlnv $vlnv "M_[lindex $ps_slaves $m_i]"]
    }

    foreach s $mem_slaves m $mem_masters { connect_bd_intf_net $s $m }
  }

  # Create interrupt controller subsystem:
  # Consists of AXI_INTC IP cores (as many as required), which are connected by an internal
  # AXI Interconnect (S_AXI port) and to the Zynq interrupt lines.
  # @param irqs List of the interrupts from the threadpool.
  # @param ps_irq_in interrupt port of host
  proc create_subsystem_intc {} {
    set irqs [arch::get_irqs]
    puts "Number of architecture interrupts: [llength $irqs]"

    # create hierarchical ports
    set s_axi [create_bd_intf_pin -mode Slave -vlnv [::tapasco::ip::get_vlnv "aximm_intf"] "S_INTC"]
    set aclk [::tapasco::subsystem::get_port "host" "clk"]
    set ic_aresetn [::tapasco::subsystem::get_port "host" "rst" "interconnect"]
    set p_aresetn [::tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set irq_out [create_bd_pin -type "intr" -dir O -to [expr "[llength $irqs] - 1"] "irq_0"]

    # create interrupt controllers and connect them to GP1
    set intcs [list]
    foreach irq $irqs {
      set intc [tapasco::ip::create_axi_irqc [format "axi_intc_%02d" [llength $intcs]]]
      connect_bd_net $irq [get_bd_pins -of $intc -filter {NAME=="intr"}]
      lappend intcs $intc
    }

    # concatenate interrupts and connect them to port
    set int_cc [tapasco::ip::create_xlconcat "int_cc" [llength $irqs]]
    for {set i 0} {$i < [llength $irqs]} {incr i} {
      connect_bd_net [get_bd_pins "[lindex $intcs $i]/irq"] [get_bd_pins "$int_cc/In$i"]
    }
    connect_bd_net [get_bd_pins "$int_cc/dout"] $irq_out

    set intcic [tapasco::ip::create_axi_ic "axi_intc_ic" 1 [llength $intcs]]
    set i 0
    foreach intc $intcs {
      set slave [get_bd_intf_pins -of $intc -filter { MODE == "Slave" }]
      set master [get_bd_intf_pins -of $intcic -filter "NAME == [format "M%02d_AXI" $i]"]
      puts "Connecting $master to $slave ..."
      connect_bd_intf_net -boundary_type upper $master $slave
      incr i
    }

    # connect internal clocks
    connect_bd_net -net intc_clock_net $aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I"}]
    # connect internal interconnect resets
    set ic_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV =~ "*:axi_interconnect:*"}] -filter {NAME == "ARESETN"}]
    connect_bd_net -net intc_ic_reset_net $ic_aresetn $ic_resets
    # connect internal peripheral resets
    set p_resets [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN"}]
    connect_bd_net -net intc_p_reset_net $p_aresetn $p_resets

    # connect S_AXI
    connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $intcic -filter {NAME == "S00_AXI"}]
  }

  # Creates the host subsystem containing the PS7.
  proc create_subsystem_host {} {
    puts "Creating Host/PS7 subsystem ..."

    set aximm_vlnv [::tapasco::ip::get_vlnv "aximm_intf"]

    set gp0_masters [list]
    lappend gp0_masters [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv "M_ARCH"]
    lappend gp0_masters [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv "M_TAPASCO"]

    set gp1_masters [list]
    lappend gp1_masters [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv "M_INTC"]
    foreach ss [::tapasco::subsystem::get_custom] {
      lappend gp1_masters [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv [format "M_%s" [string toupper $ss]]]
    }

    set gp0_ic_tree [::tapasco::create_interconnect_tree "gp0_ic_tree" [llength $gp0_masters] false]
    set gp1_ic_tree [::tapasco::create_interconnect_tree "gp1_ic_tree" [llength $gp1_masters] false]

    foreach m $gp0_masters s [get_bd_intf_pins -of_object $gp0_ic_tree -filter { MODE == Master }] {
      connect_bd_intf_net $m $s
    }
    foreach m $gp1_masters s [get_bd_intf_pins -of_object $gp1_ic_tree -filter { MODE == Master }] {
      connect_bd_intf_net $m $s
    }

    # create hierarchical ports
    set mem_slaves [list]
    foreach s [list "HP0" "HP1" "ACP"] {
      lappend mem_slaves [create_bd_intf_pin -mode Slave -vlnv $aximm_vlnv "S_$s"]
    }

    set reset_in [create_bd_pin -dir O -type rst "reset_in"]
    set irq_0 [create_bd_pin -dir I -type intr -from 7 -to 0 "irq_0"]
    set pirq_0 [create_bd_pin -dir I -type intr -from 7 -to 0 "platform_irq_0"]
    set mem_aclk [tapasco::subsystem::get_port "mem" "clk"]
    set mem_p_arstn [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
    set mem_ic_arstn [tapasco::subsystem::get_port "mem" "rst" "interconnect"]
    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_p_arstn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set host_ic_arstn [tapasco::subsystem::get_port "host" "rst" "interconnect"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_p_arstn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set design_ic_arstn [tapasco::subsystem::get_port "design" "rst" "interconnect"]

    # generate PS7 instance
    set ps [tapasco::ip::create_ps "ps7" [tapasco::get_board_preset] [tapasco::get_design_frequency]]
    puts "  PS generated, activating board preset ..."
    if {[tapasco::get_board_preset] != {}} {
      set_property -dict [list CONFIG.preset [tapasco::get_board_preset]] $ps
    }
    puts "  PS configuration ..."
    # activate ACP, HP0, HP2 and GP0/1 (+ FCLK1 @10MHz)
    set_property -dict [list \
      CONFIG.PCW_USE_M_AXI_GP0 			{1} \
      CONFIG.PCW_USE_M_AXI_GP1 			{1} \
      CONFIG.PCW_USE_S_AXI_HP0 			{1} \
      CONFIG.PCW_USE_S_AXI_HP1 			{0} \
      CONFIG.PCW_USE_S_AXI_HP2 			{1} \
      CONFIG.PCW_USE_S_AXI_HP3 			{0} \
      CONFIG.PCW_USE_S_AXI_ACP 			{1} \
      CONFIG.PCW_USE_S_AXI_GP0 			{0} \
      CONFIG.PCW_USE_S_AXI_GP1 			{0} \
      CONFIG.PCW_S_AXI_HP0_DATA_WIDTH 		{64} \
      CONFIG.PCW_S_AXI_HP2_DATA_WIDTH 		{64} \
      CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL 		{1} \
      CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 		[tapasco::get_design_frequency] \
      CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 		{10} \
      CONFIG.PCW_USE_FABRIC_INTERRUPT 		{1} \
      CONFIG.PCW_IRQ_F2P_INTR 			{1} \
      CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 		{0} \
      CONFIG.PCW_EN_CLK1_PORT 			{1} ] $ps
    puts "  PS configuration finished"

    # connect masters
    connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_GP0"] [get_bd_intf_pins -of_objects $gp0_ic_tree -filter { MODE == Slave }]
    connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_GP1"] [get_bd_intf_pins -of_objects $gp1_ic_tree -filter { MODE == Slave }]

    # connect slaves
    set ps_mem_slaves [list \
      [get_bd_intf_pins "$ps/S_AXI_HP0"] \
      [get_bd_intf_pins "$ps/S_AXI_HP2"] \
      [get_bd_intf_pins "$ps/S_AXI_ACP"] \
    ]
    foreach ms $mem_slaves pms $ps_mem_slaves { connect_bd_intf_net $ms $pms }

    # connect interrupts
    set irq_cc [tapasco::ip::create_xlconcat "irq_cc" 2]
    connect_bd_net $pirq_0 [get_bd_pins "$irq_cc/In0"]
    connect_bd_net $irq_0 [get_bd_pins "$irq_cc/In1"]
    set_property -dict [list CONFIG.IN0_WIDTH.VALUE_SRC USER CONFIG.IN1_WIDTH.VALUE_SRC USER] $irq_cc
    set_property -dict [list CONFIG.IN0_WIDTH {8} CONFIG.IN1_WIDTH {8}] $irq_cc
    connect_bd_net [get_bd_pins -of_objects $irq_cc -filter { DIR == O }] [get_bd_pins "$ps/IRQ_F2P"]

    # connect reset
    connect_bd_net [get_bd_pins "$ps/FCLK_RESET0_N"] $reset_in

    # connect memory slaves to memory clock and reset
    connect_bd_net $mem_aclk [get_bd_pins -of_objects $ps -filter {NAME =~ "S*ACLK"}]

    # connect clocks
    connect_bd_net $host_aclk \
      [get_bd_pins -of_objects [get_bd_cells] -filter { TYPE == clk && DIR == I && NAME !~ "S*ACLK"}]
    connect_bd_net $host_ic_arstn \
      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == rst && DIR == I && NAME =~ *interconnect* }]
    connect_bd_net $host_p_arstn \
      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == rst && DIR == I && NAME =~ *peripheral* }]
  }

  proc get_debug_nets {} {
    set host_prefix "system_i[::tapasco::subsystem::get host]"
    set ps_prefix "$host_prefix/ps7"
    set int_prefix "system_i[::tapasco::subsystem::get intc]_"
    set tp_prefix "system_i[::tapasco::subsystem::get arch]_"

    set ret [list \
        "$host_prefix/irq_out*" \
\
  "${host_prefix}_M_AXI_GP0_RDATA*" \
  "${host_prefix}_M_AXI_GP0_WDATA*" \
  "${host_prefix}_M_AXI_GP0_ARADDR*" \
  "${host_prefix}_M_AXI_GP0_AWADDR*" \
  "${host_prefix}_M_AXI_GP0_AWVALID" \
  "${host_prefix}_M_AXI_GP0_AWREADY" \
  "${host_prefix}_M_AXI_GP0_ARVALID" \
  "${host_prefix}_M_AXI_GP0_ARREADY" \
  "${host_prefix}_M_AXI_GP0_WVALID" \
  "${host_prefix}_M_AXI_GP0_WREADY" \
  "${host_prefix}_M_AXI_GP0_RVALID" \
  "${host_prefix}_M_AXI_GP0_RREADY" \
\
  "${host_prefix}_M_AXI_GP1_RDATA*" \
  "${host_prefix}_M_AXI_GP1_WDATA*" \
  "${host_prefix}_M_AXI_GP1_ARADDR*" \
  "${host_prefix}_M_AXI_GP1_AWADDR*" \
  "${host_prefix}_M_AXI_GP1_AWVALID" \
  "${host_prefix}_M_AXI_GP1_AWREADY" \
  "${host_prefix}_M_AXI_GP1_ARVALID" \
  "${host_prefix}_M_AXI_GP1_ARREADY" \
  "${host_prefix}_M_AXI_GP1_WVALID" \
  "${host_prefix}_M_AXI_GP1_WREADY" \
  "${host_prefix}_M_AXI_GP1_RVALID" \
  "${host_prefix}_M_AXI_GP1_RREADY" \
      ]

    if {[llength [get_nets "${ps_prefix}/S_AXI_HP0_RDATA*"]] > 0} {
      lappend ret [list \
  "${ps_prefix}/S_AXI_HP0_RDATA*" \
  "${ps_prefix}/S_AXI_HP0_WDATA*" \
  "${ps_prefix}/S_AXI_HP0_ARADDR*" \
  "${ps_prefix}/S_AXI_HP0_AWADDR*" \
  "${ps_prefix}/S_AXI_HP0_AWVALID" \
  "${ps_prefix}/S_AXI_HP0_AWREADY" \
  "${ps_prefix}/S_AXI_HP0_ARVALID" \
  "${ps_prefix}/S_AXI_HP0_ARREADY" \
  "${ps_prefix}/S_AXI_HP0_WVALID" \
  "${ps_prefix}/S_AXI_HP0_WREADY" \
  "${ps_prefix}/S_AXI_HP0_WSTRB*" \
  "${ps_prefix}/S_AXI_HP0_RVALID" \
  "${ps_prefix}/S_AXI_HP0_RREADY" \
  "${ps_prefix}/S_AXI_HP0_ARBURST*" \
  "${ps_prefix}/S_AXI_HP0_AWBURST*" \
  "${ps_prefix}/S_AXI_HP0_ARLEN*" \
  "${ps_prefix}/S_AXI_HP0_AWLEN*" \
  "${ps_prefix}/S_AXI_HP0_WLAST" \
  "${ps_prefix}/S_AXI_HP0_RLAST" \
     ]
   }

    if {[llength [get_nets "${ps_prefix}/S_AXI_HP2_RDATA*"]] > 0} {
      lappend ret [list \
  "${ps_prefix}/S_AXI_HP2_RDATA*" \
  "${ps_prefix}/S_AXI_HP2_WDATA*" \
  "${ps_prefix}/S_AXI_HP2_ARADDR*" \
  "${ps_prefix}/S_AXI_HP2_AWADDR*" \
  "${ps_prefix}/S_AXI_HP2_AWVALID" \
  "${ps_prefix}/S_AXI_HP2_AWREADY" \
  "${ps_prefix}/S_AXI_HP2_ARVALID" \
  "${ps_prefix}/S_AXI_HP2_ARREADY" \
  "${ps_prefix}/S_AXI_HP2_WVALID" \
  "${ps_prefix}/S_AXI_HP2_WREADY" \
  "${ps_prefix}/S_AXI_HP2_WSTRB*" \
  "${ps_prefix}/S_AXI_HP2_RVALID" \
  "${ps_prefix}/S_AXI_HP2_RREADY" \
  "${ps_prefix}/S_AXI_HP2_ARBURST*" \
  "${ps_prefix}/S_AXI_HP2_AWBURST*" \
  "${ps_prefix}/S_AXI_HP2_ARLEN*" \
  "${ps_prefix}/S_AXI_HP2_AWLEN*" \
  "${ps_prefix}/S_AXI_HP2_WLAST" \
  "${ps_prefix}/S_AXI_HP2_RLAST" \
      ]
    }

    if {[llength [get_nets "${ps_prefix}/S_AXI_ACP_RDATA*"]] > 0} {
      lappend ret [list \
  "${ps_prefix}/S_AXI_ACP_RDATA*" \
  "${ps_prefix}/S_AXI_ACP_WDATA*" \
  "${ps_prefix}/S_AXI_ACP_ARADDR*" \
  "${ps_prefix}/S_AXI_ACP_AWADDR*" \
  "${ps_prefix}/S_AXI_ACP_AWVALID" \
  "${ps_prefix}/S_AXI_ACP_AWREADY" \
  "${ps_prefix}/S_AXI_ACP_ARVALID" \
  "${ps_prefix}/S_AXI_ACP_ARREADY" \
  "${ps_prefix}/S_AXI_ACP_WVALID" \
  "${ps_prefix}/S_AXI_ACP_WREADY" \
  "${ps_prefix}/S_AXI_ACP_WSTRB*" \
  "${ps_prefix}/S_AXI_ACP_RVALID" \
  "${ps_prefix}/S_AXI_ACP_RREADY" \
  "${ps_prefix}/S_AXI_ACP_ARBURST*" \
  "${ps_prefix}/S_AXI_ACP_AWBURST*" \
  "${ps_prefix}/S_AXI_ACP_ARLEN*" \
  "${ps_prefix}/S_AXI_ACP_AWLEN*" \
  "${ps_prefix}/S_AXI_ACP_WLAST" \
  "${ps_prefix}/S_AXI_ACP_RLAST" \
      ]
    }
    return $ret
  }
}
