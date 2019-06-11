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
# @file		zynqmp.tcl
# @brief	MPSoC platform implementation: Up to 16 instances of AXI Interrupt Controllers
#         are instantiated, depending on the number interrupt sources returned by the architecture.
# @author	Jaco A. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
#
  # check if TAPASCO_HOME env var is set
  if {![info exists ::env(TAPASCO_HOME)]} {
    puts "Could not find TaPaSCo root directory, please set environment variable 'TAPASCO_HOME'."
    exit 1
  }

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/zynqmp/plugins" "*.tcl"] {
    source -notrace $f
  }

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/${platform_dirname}/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list [::tapasco::get_platform_num_slots]]
  }

  proc get_pe_base_address {} {
    return 0x00A1000000
  }

  proc get_address_map {{pe_base ""}} {
    set max32 [expr "1 << 32"]
    if {$pe_base == ""} { set pe_base [get_pe_base_address] }
    puts "Computing addresses for PEs ..."
    set peam [::arch::get_address_map $pe_base]
    puts "Computing addresses for masters ..."
    foreach m [::tapasco::get_aximm_interfaces [get_bd_cells -filter "PATH !~ [::tapasco::subsystem::get arch]/*"]] {
      switch -glob [get_property NAME $m] {
        "M_TAPASCO" { foreach {base stride range comp} [list 0x00A0000000 0       0 "PLATFORM_COMPONENT_STATUS"] {} }
        "M_INTC"    { foreach {base stride range comp} [list 0x00B0000000 0x10000 0 "PLATFORM_COMPONENT_INTC0"] {} }
        "M_ARCH"    { set base "skip" }
        default     { foreach {base stride range comp} [list 0 0 0 ""] {} }
      }
      if {$base != "skip"} { set peam [addressmap::assign_address $peam $m $base $stride $range $comp] }
    }
    assign_bd_address [get_bd_addr_segs {host/zynqmp/SAXIGP2/HP0_DDR_HIGH }]
    assign_bd_address [get_bd_addr_segs {host/zynqmp/SAXIGP4/HP2_DDR_HIGH }]
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
    set clk_mode [lindex [get_board_part_interfaces -filter { NAME =~ *sys*cl*k }] 0]

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
      if {[get_property VLNV $clk_mode] == "xilinx.com:interface:diff_clock_rtl:1.0"} {
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
    set ps_slaves [list "HP0" "HP1"]
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
    set design_aclk [::tapasco::subsystem::get_port "design" "clk"]
    set ic_aresetn [::tapasco::subsystem::get_port "design" "rst" "interconnect"]
    set p_aresetn [::tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set h_p_aresetn [::tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
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
    connect_bd_net -net intc_clock_net $design_aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I" && NAME !~ "S00_ACLK"}]
    connect_bd_net $aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I" && NAME == "S00_ACLK"}]
    # connect internal interconnect resets
    set ic_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV =~ "*:axi_interconnect:*"}] -filter {NAME == "ARESETN"}]
    connect_bd_net -net intc_ic_reset_net $ic_aresetn $ic_resets
    # connect internal peripheral resets
    set p_resets [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN" && NAME !~ "S00_ARESETN"}]
    connect_bd_net -net intc_p_reset_net $p_aresetn $p_resets

    set p_resets
    connect_bd_net $h_p_aresetn [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN" && NAME == "S00_ARESETN"}]

    # connect S_AXI
    connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $intcic -filter {NAME == "S00_AXI"}]
  }


  # Creates the host subsystem containing the PS7.
  proc create_subsystem_host {} {
    puts "Creating Host/UltraPS subsystem ..."

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
    set hp_ports [list "HP0" "HP1"]
    set mem_slaves [list]
    foreach s $hp_ports {
      lappend mem_slaves [create_bd_intf_pin -mode Slave -vlnv $aximm_vlnv "S_$s"]
    }

    set reset_in [create_bd_pin -dir O -type rst "reset_in"]
    set irq_0 [create_bd_pin -dir I -type intr -from 15 -to 0 "irq_0"]
    set mem_aclk [tapasco::subsystem::get_port "mem" "clk"]
    set mem_p_arstn [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
    set mem_ic_arstn [tapasco::subsystem::get_port "mem" "rst" "interconnect"]
    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_p_arstn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set host_ic_arstn [tapasco::subsystem::get_port "host" "rst" "interconnect"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_p_arstn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set design_ic_arstn [tapasco::subsystem::get_port "design" "rst" "interconnect"]

    set mem_offsets [list]
    foreach s $mem_slaves n $hp_ports {
      set offset [tapasco::ip::create_axioffset "${n}_offset"]
      connect_bd_net [get_bd_pins $offset/CLK] $design_aclk
      connect_bd_net [get_bd_pins $offset/RST_N] $design_p_arstn
      connect_bd_intf_net $s [get_bd_intf_pins $offset/S_AXI]
      set bic [tapasco::ip::create_axi_ic "${n}_offset_ic" 1 1]
      connect_bd_intf_net [get_bd_intf_pins $bic/S00_AXI] [get_bd_intf_pin $offset/M_AXI]
      lappend mem_offsets [get_bd_intf_pin $bic/M00_AXI]
      connect_bd_net $mem_aclk \
        [get_bd_pins -of_objects $bic -filter { TYPE == clk && DIR == I && NAME !~ "S00_ACLK"}]
      connect_bd_net $design_aclk \
        [get_bd_pins -of_objects $bic -filter { TYPE == clk && DIR == I && NAME =~ "S00_ACLK"}]

      connect_bd_net $mem_ic_arstn \
        [get_bd_pins -of_objects $bic -filter { TYPE == rst && DIR == I && NAME =~ "ARESETN" }]

      connect_bd_net $mem_p_arstn \
        [get_bd_pins -of_objects $bic -filter { TYPE == rst && DIR == I && NAME =~ "M00_ARESETN" }]

      connect_bd_net $design_p_arstn \
        [get_bd_pins -of_objects $bic -filter { TYPE == rst && DIR == I && NAME =~ "S00_ARESETN" }]
    }

    # generate PS MPSoC instance. Default values are fine
    set ps [tapasco::ip::create_ultra_ps "zynqmp" [tapasco::get_board_preset] [tapasco::get_design_frequency]]

    puts "  PS generated..."
    puts "  PS configuration ..."

    # activate ACP, HP0, HP2 and GP0/1 (+ FCLK1 @10MHz)
    set_property -dict [list \
      CONFIG.PSU__FPGA_PL1_ENABLE {1} \
      CONFIG.PSU__USE__S_AXI_GP2 {1}  \
      CONFIG.PSU__USE__S_AXI_GP4 {1}  \
      CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ [tapasco::get_design_frequency] \
      CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {10} \
      CONFIG.PSU__USE__IRQ0 {1} \
      CONFIG.PSU__USE__IRQ1 {1} \
      CONFIG.PSU__HIGH_ADDRESS__ENABLE {1} \
      CONFIG.PSU__USE__M_AXI_GP0 {1} \
      CONFIG.PSU__USE__M_AXI_GP1 {1} \
      CONFIG.PSU__USE__M_AXI_GP2 {0}
      ] $ps
    puts "  PS configuration finished"

    # connect masters
    connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_HPM0_FPD"] [get_bd_intf_pins -of_objects $gp0_ic_tree -filter { MODE == Slave }]
    connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_HPM1_FPD"] [get_bd_intf_pins -of_objects $gp1_ic_tree -filter { MODE == Slave }]

    # connect slaves
    set ps_mem_slaves [list \
      [get_bd_intf_pins "$ps/S_AXI_HP0_FPD"] \
      [get_bd_intf_pins "$ps/S_AXI_HP2_FPD"]
    ]
    foreach ms $mem_offsets pms $ps_mem_slaves { connect_bd_intf_net $ms $pms }

    # connect interrupt
    set irq_top [tapasco::ip::create_xlslice irq_top 16 0]
    set_property -dict [list CONFIG.DIN_FROM {7} CONFIG.DIN_WIDTH {16} CONFIG.DOUT_WIDTH {8} CONFIG.DIN_TO {0}] $irq_top
    connect_bd_net [get_bd_pins $irq_0] [get_bd_pins $irq_top/Din]
    connect_bd_net [get_bd_pins $irq_top/Dout] [get_bd_pins $ps/pl_ps_irq0]
    set irq_bot [tapasco::ip::create_xlslice irq_bot 16 0]
    set_property -dict [list CONFIG.DIN_FROM {15} CONFIG.DIN_WIDTH {16} CONFIG.DOUT_WIDTH {8} CONFIG.DIN_TO {8}] $irq_bot
    connect_bd_net [get_bd_pins $irq_0] [get_bd_pins $irq_bot/Din]
    connect_bd_net [get_bd_pins $irq_bot/Dout] [get_bd_pins $ps/pl_ps_irq1]

    # connect reset
    connect_bd_net [get_bd_pins "$ps/pl_resetn0"] $reset_in

    # connect memory slaves to memory clock and reset
    connect_bd_net $mem_aclk [get_bd_pins -of_objects $ps -filter {NAME =~ "s*hp*aclk"}]

    # connect clocks
    # Host side
    connect_bd_net $host_aclk \
      [get_bd_pins -of_objects $ps -filter { TYPE == clk && DIR == I && NAME !~ "s*hp*aclk"}]
    connect_bd_net $host_aclk \
      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == clk && DIR == I && NAME =~ "s_aclk"}]
    connect_bd_net $host_aclk \
      [get_bd_pins -of_objects $gp1_ic_tree -filter { TYPE == clk && DIR == I && NAME =~ "m_aclk"}]

    connect_bd_net $host_ic_arstn \
      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == rst && DIR == I && NAME =~ "s_interconnect*" }]
    connect_bd_net $host_p_arstn \
      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == rst && DIR == I && NAME =~ "s_peripheral*" }]

    connect_bd_net $host_ic_arstn \
      [get_bd_pins -of_objects $gp1_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_interconnect*" }]
    connect_bd_net $host_p_arstn \
      [get_bd_pins -of_objects $gp1_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_peripheral*" }]

    # Design side
    connect_bd_net $design_aclk \
      [get_bd_pins -of_objects [list $gp0_ic_tree] -filter { TYPE == clk && DIR == I && NAME =~ "m_aclk"}]

    connect_bd_net $design_ic_arstn \
      [get_bd_pins -of_objects $gp0_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_interconnect*" }]
    connect_bd_net $design_p_arstn \
      [get_bd_pins -of_objects $gp0_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_peripheral*" }]

      save_bd_design

  }