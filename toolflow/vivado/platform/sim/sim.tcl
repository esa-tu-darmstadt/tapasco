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
  set platform_dirname "sim"

  if { [::tapasco::vivado_is_newer "2018.1"] == 0 } {
    puts "Vivado [version -short] is too old to support MPSoC."
    exit 1
  }

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/zynqmp/plugins" "*.tcl"] {
    source -notrace $f
  }

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/${platform_dirname}/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list [::tapasco::get_platform_num_slots]]
  }

  proc get_pe_base_address {} {
    return 0x0
    return 0x00A0000000
  }

  proc get_platform_base_address {} {
    return 0x0010000000
    return 0x00B0000000
  }

  proc get_address_map {{pe_base ""}} {
    set max32 [expr "1 << 32"]
    if {$pe_base == ""} { set pe_base [get_pe_base_address] }
    puts "Computing addresses for PEs ..."
    set peam [::arch::get_address_map $pe_base]
    puts "Computing addresses for masters ..."
        # "M_INTC"    { foreach {base stride range comp} [list 0x00B0010000 0x10000 0 "PLATFORM_COMPONENT_INTC0"] {} }
    foreach m [::tapasco::get_aximm_interfaces [get_bd_cells -filter "PATH !~ [::tapasco::subsystem::get arch]/*"]] {
      switch -glob [get_property NAME $m] {
        "M_TAPASCO" { foreach {base stride range comp} [list 0x0010000000 0       0 "PLATFORM_COMPONENT_STATUS"] {} }

        "M_ARCH"    { set base "skip" }
        default     { foreach {base stride range comp} [list 0 0 0 ""] {} }
      }
      if {$base != "skip"} { set peam [addressmap::assign_address $peam $m $base $stride $range $comp] }
    }
    return $peam
  }

  proc modify_address_map_sim {map} {
    puts $map
    # set segs [get_bd_addrs_segs -addressables -of_objects [get_bd]]
    assign_bd_address
    # assign_bd_address -target_address_space /S_ARCH [get_bd_addr_segs /arch*] -force
    # assign_bd_address -target_address_space /S_TAPASCO [get_bd_addr_segs /tapasco*] -force
  }

  proc get_ignored_segments { } {
    set ignored [list]
    return $ignored
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_DDR_LOW"
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_LPS_OCM"
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_PCIE_LOW"
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_QSPI"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_DDR_LOW"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_LPS_OCM"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_PCIE_LOW"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_QSPI"
    return $ignored
  }

  proc number_of_interrupt_controllers {} {
    return 0
    set no_pes [llength [arch::get_processing_elements]]
    return [expr "$no_pes > 96 ? 4 : ($no_pes > 64 ? 3 : ($no_pes > 32 ? 2 : 1))"]
  }

  proc __disabled__create_subsystem_tapasco {} {
    puts "  creating slave port S_TAPASCO ..."
    set port [create_bd_intf_pin -vlnv [tapasco::ip::get_vlnv "aximm_intf"] -mode Slave "S_TAPASCO"]
    puts "  instantiating custom status core ..."
    set tapasco_status [tapasco::ip::create_tapasco_status "tapasco_status"]
    update_ip_catalog -rebuild

    puts "  wiring ..."
    connect_bd_intf_net $port [get_bd_intf_pins -of_objects $tapasco_status -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]
    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] [get_bd_pins -of_objects $tapasco_status -filter {TYPE == clk && DIR == I}]
    connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] [get_bd_pins -of_objects $tapasco_status -filter {TYPE == rst && DIR == I}]
    puts "  done!"

    #### Make TAPASCO AXI port external ####
    set freqs [::tapasco::get_frequencies]
    set instance [current_bd_instance .]
    current_bd_instance /tapasco
    puts [current_bd_instance .]
    set s_tapasco [get_bd_intf_pins -filter {NAME == S_TAPASCO}]
    puts "bd intf pins is [get_bd_intf_pins]"
    puts "bd pins is [get_bd_pins]"
    puts "s_tapasco is $s_tapasco"
    puts "name of $s_tapasco is [get_property NAME $s_tapasco]"
    set s_tapasco_name [get_property NAME $s_tapasco]
    puts [get_bd_intf_pins -filter {NAME == S_TAPASCO}]
    current_bd_instance /
    make_bd_intf_pins_external $s_tapasco
    set port_name [format %s_0 [get_property NAME $s_tapasco]]
    set ext_port [get_bd_intf_ports -filter "NAME == $port_name"]

    puts "bd cells tapasco [get_bd_cells tapasco]"
    puts "bd intf pins [get_bd_intf_pins -filter {NAME == S_TAPASCO} -of_objects [get_bd_cells tapasco]]"
    puts "property name of S_TAPASCO [get_property NAME [get_bd_intf_pins -filter {NAME == S_TAPASCO} -of_objects [get_bd_cells tapasco]]]"


    set_property NAME $s_tapasco_name [get_bd_intf_ports -filter "NAME == [format %s_0 [get_property NAME [get_bd_intf_pins -filter {NAME == S_TAPASCO} -of_objects [get_bd_cells tapasco]]]]"]
    puts "host clk [lindex $freqs [expr [lsearch $freqs host] + 1]]"
    puts "ext port is $ext_port"
    set_property CONFIG.FREQ_HZ [expr [lindex $freqs [expr [lsearch $freqs host] + 1]] * 1000000] $ext_port
    current_bd_instance $instance
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
    set_property -dict [list CONFIG.USE_LOCKED {true} CONFIG.USE_RESET {false}] $clk_wiz
    set instance [current_bd_instance .]
    make_bd_pins_external [get_bd_pins $clk_wiz/locked]
    current_bd_instance ..
    set_property name locked [get_bd_ports locked_0]
    # set_property name reset_in [get_bd_ports reset_in_0]
    # set_property name host_clk [get_bd_ports host_clk_0]
    # set_property name design_clk [get_bd_ports design_clk_0]
    current_bd_instance $instance

    set clk_mode [lindex [get_board_part_interfaces -filter { NAME =~ *sys*cl*k }] 0]

    if {$clk_mode != ""} {
      set_property CONFIG.CLK_IN1_BOARD_INTERFACE $clk_mode $clk_wiz
    } else {
      puts "Could not find a board interface for the sys clock. Trying to use processing system clock."
      set ps_clk_in [create_bd_pin -dir I -type clk "ps_clk_in"]
      # make_bd_pins_external [get_bd_pins ps_clk_in]
      # set instance [current_bd_instance .]
      # current_bd_instance ..
      # set_property name ps_clk_in [get_bd_ports ps_clk_in_0]
      # current_bd_instance $instance
    }

    # check if external port already exists, re-use
    if {[get_bd_ports -quiet "/$clk_mode"] != {}} {
      puts "entered clk_mode if"
      # connect existing top-level port
      connect_bd_net [get_bd_ports "/$clk_mode"] [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $clk_wiz]
      # use PLL primitive for all but the first subsystem (MMCMs are limited)
      set_property -dict [list CONFIG.PRIMITIVE {PLL} CONFIG.USE_MIN_POWER {true}] $clk_wiz
    } {
      # apply board automation to create top-level port
      if {($clk_mode != "") && ([get_property VLNV $clk_mode] == "xilinx.com:interface:diff_clock_rtl:1.0")} {
        set cport [get_bd_intf_pins -of_objects $clk_wiz]
      } {
        set cport [get_bd_pins -filter {DIR == I} -of_objects $clk_wiz]
      }
      puts "  clk_wiz: $clk_wiz, cport: $cport"
      if {$cport != {}} {
        if {[info exists ps_clk_in]} {
          # connect ps clock in with clk_wizard
          connect_bd_net $ps_clk_in $cport
        } else {
          # apply board automation
          apply_bd_automation -rule xilinx.com:bd_rule:board -config "Board_Interface $clk_mode" $cport
          puts "board automation worked, moving on"
        }
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
    # set mem_slaves  [list]
    # set mem_masters [list]
    # set arch_masters [::arch::get_masters]
    # set ps_slaves [list "HPC0" "HP1"]
    # puts "Creating memory slave ports for [llength $arch_masters] masters ..."
    # if {[llength $arch_masters] > [llength $ps_slaves]} {
    #   error "  trying to connect [llength $arch_masters] architecture masters, " \
    #     "but only [llength $ps_slaves] memory interfaces are available"
    # }
    # set m_i 0
    # foreach m $arch_masters {
    #   set name [regsub {^M_(.*)} [get_property NAME $m] {S_\1}]
    #   puts "  $m -> $name"
    #   lappend mem_slaves [create_bd_intf_pin -mode Slave -vlnv [get_property VLNV $m] $name]
    #   lappend mem_masters [create_bd_intf_pin -mode Master -vlnv [::tapasco::ip::get_vlnv "aximm_intf"] "M_[lindex $ps_slaves $m_i]"]
    #   incr m_i
    # }
#
    # if {$m_i == 0} {
    #   set name [format "S_%s" [lindex $ps_slaves 0]]
    #   set vlnv [::tapasco::ip::get_vlnv "aximm_intf"]
    #   lappend mem_slaves [create_bd_intf_pin -mode Slave -vlnv $vlnv $name]
    #   lappend mem_masters [create_bd_intf_pin -mode Master -vlnv $vlnv "M_[lindex $ps_slaves $m_i]"]
    # }
#
    # foreach s $mem_slaves m $mem_masters { connect_bd_intf_net $s $m }
  }

  # Create interrupt controller subsystem:
  # Consists of AXI_INTC IP cores (as many as required), which are connected by an internal
  # AXI Interconnect (S_AXI port) and to the Zynq interrupt lines.
  proc create_subsystem_intc {} {
    # create hierarchical ports
    # set s_axi [create_bd_intf_pin -mode Slave -vlnv [::tapasco::ip::get_vlnv "aximm_intf"] "S_INTC"]
    # set aclk [::tapasco::subsystem::get_port "host" "clk"]
    # set design_aclk [::tapasco::subsystem::get_port "design" "clk"]
    # set ic_aresetn [::tapasco::subsystem::get_port "design" "rst" "interconnect"]
    # set p_aresetn [::tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    # set h_p_aresetn [::tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
#
    # set int_in [::tapasco::ip::create_interrupt_in_ports]
    set int_list [::tapasco::ip::get_interrupt_list]
    set int_mapping [list]
    set int_design_total 0
    foreach {name clk} $int_list {
      lappend int_mapping $int_design_total
      incr int_design_total
    }

    ::tapasco::ip::set_interrupt_mapping $int_mapping

#
    # puts "Starting mapping of interrupts $int_list"
#
    # set int_design_total 0
    # set int_design 0
#
    # set intcs_last [tapasco::ip::create_axi_irqc [format "axi_intc_0"]]
    # set concats_last [tapasco::ip::create_xlconcat "axi_intc_0_cc" 32]
    # connect_bd_net [get_bd_pins $concats_last/dout] [get_bd_pins ${intcs_last}/intr]
    # set intcs [list $intcs_last]
#
    # foreach {name clk} $int_list port $int_in {
    #   puts "Connecting ${name} (Clk: ${clk}) to ${port}"
#
    #   if { $int_design >= 32 } {
    #     set n [llength $intcs]
    #     set intcs_last [tapasco::ip::create_axi_irqc [format "axi_intc_${n}"]]
    #     set concats_last [tapasco::ip::create_xlconcat "axi_intc_${n}_cc" 32]
    #     connect_bd_net [get_bd_pins $concats_last/dout] [get_bd_pins ${intcs_last}/intr]
#
    #     lappend intcs $intcs_last
#
    #     set int_design 0
    #   }
    #   connect_bd_net ${port} [get_bd_pins ${concats_last}/In${int_design}]
#
    #   lappend int_mapping $int_design_total
#
    #   incr int_design
    #   incr int_design_total
    # }
#
    # ::tapasco::ip::set_interrupt_mapping $int_mapping
#
    # set irq_out [create_bd_pin -type "intr" -dir O -to [expr "[llength $intcs] - 1"] "irq_0"]
#
    # # concatenate interrupts and connect them to port
    # set int_cc [tapasco::ip::create_xlconcat "int_cc" [llength $intcs]]
    # for {set i 0} {$i < [llength $intcs]} {incr i} {
    #   connect_bd_net [get_bd_pins "[lindex $intcs $i]/irq"] [get_bd_pins "$int_cc/In$i"]
    # }
    # connect_bd_net [get_bd_pins "$int_cc/dout"] $irq_out
#
    # set intcic [tapasco::ip::create_axi_ic "axi_intc_ic" 1 [llength $intcs]]
    # set i 0
    # foreach intc $intcs {
    #   set slave [get_bd_intf_pins -of $intc -filter { MODE == "Slave" }]
    #   set master [get_bd_intf_pins -of $intcic -filter "NAME == [format "M%02d_AXI" $i]"]
    #   puts "Connecting $master to $slave ..."
    #   connect_bd_intf_net -boundary_type upper $master $slave
    #   incr i
    # }
#
    # # connect internal clocks
    # connect_bd_net -net intc_clock_net $design_aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I" && NAME !~ "S00_ACLK"}]
    # connect_bd_net $aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I" && NAME == "S00_ACLK"}]
    # # connect internal interconnect resets
    # set ic_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV =~ "*:axi_interconnect:*"}] -filter {NAME == "ARESETN"}]
    # connect_bd_net -net intc_ic_reset_net $ic_aresetn $ic_resets
    # # connect internal peripheral resets
    # set p_resets [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN" && NAME !~ "S00_ARESETN"}]
    # connect_bd_net -net intc_p_reset_net $p_aresetn $p_resets
#
    # set p_resets
    # connect_bd_net $h_p_aresetn [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN" && NAME == "S00_ARESETN"}]
#
    # # connect S_AXI
    # connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $intcic -filter {NAME == "S00_AXI"}]
  }


  # Creates the host subsystem containing the PS7.
  proc create_subsystem_host {} {
#    puts "Creating Host/UltraPS subsystem ..."
#
    set aximm_vlnv [::tapasco::ip::get_vlnv "aximm_intf"]
    set freqs [::tapasco::get_frequencies]
    puts "freqs: $freqs"

    #### Make ARCH AXI port external ####
    # set instance [current_bd_instance .]
    # current_bd_instance /arch
    # set s_arch [get_bd_intf_pins -filter {NAME == S_ARCH}]
    # set s_arch_name [get_property NAME $s_arch]
    # puts [get_bd_intf_pins -filter {NAME == S_ARCH}]
    # puts "s_arch is $s_arch"
    # current_bd_instance /
    # make_bd_intf_pins_external $s_arch
    # set port_name [format %s_0 [get_property NAME $s_arch]]
    # set ext_port [get_bd_intf_ports -filter "NAME == $port_name"]
#
#
    # puts "bd cells arch [get_bd_cells arch]"
    # puts "bd intf pins [get_bd_intf_pins -filter {NAME == S_ARCH} -of_objects [get_bd_cells arch]]"
    # puts "property name of S_ARCH [get_property NAME [get_bd_intf_pins -filter {NAME == S_ARCH} -of_objects [get_bd_cells arch]]]"
#
#
    # set_property NAME $s_arch_name [get_bd_intf_ports -filter "NAME == [format %s_0 [get_property NAME [get_bd_intf_pins -filter {NAME == S_ARCH} -of_objects [get_bd_cells arch]]]]"]
    # puts "design clk [lindex $freqs [expr [lsearch $freqs design] + 1]]"
    # puts "ext port is $ext_port"
    # set_property CONFIG.FREQ_HZ [expr [lindex $freqs [expr [lsearch $freqs design] + 1]] * 1000000] $ext_port
    # current_bd_instance $instance


    set reset_in [create_bd_pin -dir O -type rst "reset_in"]
    set instance [current_bd_instance .]
    set name_external_rst "ext_reset_in"
    set external_reset_in [create_bd_pin -dir I -type rst $name_external_rst]
    connect_bd_net $reset_in $external_reset_in
    make_bd_pins_external $external_reset_in
    current_bd_instance
    set_property NAME $name_external_rst [get_bd_ports -filter "NAME == [format %s_0 $name_external_rst]"]
    current_bd_instance $instance

    if {[get_bd_pins /clocks_and_resets/ps_clk_in] != {}} {
      puts "Found pin in clock subsystem that requires a clock input from the processing system."
      set ps_clk_in [create_bd_pin -dir O -type clk "ps_clk_in"]
      set instance [current_bd_instance .]
      set name_external "ext_ps_clk_in"
      set external_ps_clk_in [create_bd_pin -dir I -type clk $name_external]
      connect_bd_net $ps_clk_in $external_ps_clk_in
      make_bd_pins_external $external_ps_clk_in
      current_bd_instance
      set_property NAME $name_external [get_bd_ports -filter "NAME == [format %s_0 $name_external]"]
      current_bd_instance $instance
    }

    set interrupts [::tapasco::ip::create_interrupt_in_ports]
    set int_outs [list]
    foreach int $interrupts {
      set int_name "ext_[get_property NAME $int]"
      set port [create_bd_pin -type INTR -dir O $int_name]
      connect_bd_net $int $port
      set instance [current_bd_instance .]
      make_bd_pins_external $port
      current_bd_instance
      set_property NAME $int_name [get_bd_ports -filter "NAME == [format %s_0 $int_name]"]
      current_bd_instance $instance
    }

    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_aclk_name "ext_[get_property NAME $host_aclk]"
    set ext_host_aclk [create_bd_pin -dir O -type clk $host_aclk_name]
    connect_bd_net $host_aclk $ext_host_aclk
    set instance [current_bd_instance .]
    make_bd_pins_external $ext_host_aclk
    current_bd_instance
    set_property NAME $host_aclk_name [get_bd_ports -filter "NAME == [format %s_0 $host_aclk_name]"]
    current_bd_instance $instance

    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aclk_name "ext_[get_property NAME $design_aclk]"
    set ext_design_aclk [create_bd_pin -dir O -type clk $design_aclk_name]
    connect_bd_net $design_aclk $ext_design_aclk
    set instance [current_bd_instance .]
    make_bd_pins_external $ext_design_aclk
    current_bd_instance
    set_property NAME $design_aclk_name [get_bd_ports -filter "NAME == [format %s_0 $design_aclk_name]"]
    current_bd_instance $instance

    set smartconnect [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0]
    set_property -dict [list CONFIG.NUM_MI {2} CONFIG.NUM_SI {1} CONFIG.NUM_CLKS {3} CONFIG.HAS_ARESETN {0}] $smartconnect
    set m_arch [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv "M_ARCH"]
    set m_tapasco [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv "M_TAPASCO"]
    connect_bd_intf_net $m_arch [get_bd_intf_pins -of_objects $smartconnect -filter {NAME == M00_AXI}]
    connect_bd_intf_net $m_tapasco [get_bd_intf_pins -of_objects $smartconnect -filter {NAME == M01_AXI}]

    set mem_aclk [tapasco::subsystem::get_port "mem" "clk"]
    set aclk0 [get_bd_pins -of_objects $smartconnect -filter {NAME == aclk}]
    set aclk1 [get_bd_pins -of_objects $smartconnect -filter {NAME == aclk1}]
    set aclk2 [get_bd_pins -of_objects $smartconnect -filter {NAME == aclk2}]

    save_bd_design

    connect_bd_net $host_aclk $aclk0
    connect_bd_net $design_aclk $aclk1
    connect_bd_net $mem_aclk $aclk2
    set instance [current_bd_instance]
    make_bd_intf_pins_external [get_bd_intf_pins -of_object $smartconnect -filter {NAME == S00_AXI}]
    set s_axi_ext [get_bd_intf_ports -filter {NAME == S00_AXI_0}]
    set_property NAME S_AXI $s_axi_ext
    set ext_design_clk [get_bd_ports -filter {NAME == ext_design_clk}]
    set_property CONFIG.ASSOCIATED_BUSIF {S_AXI} $ext_design_clk
    current_bd_instance $instance


#    set design_p_arstn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
#    set design_ic_arstn [tapasco::subsystem::get_port "design" "rst" "interconnect"]
#
#    set mem_offsets [list]
#    foreach s $mem_slaves n $hp_ports {
#      set offset [tapasco::ip::create_axioffset "${n}_offset"]
#      connect_bd_net [get_bd_pins $offset/CLK] $design_aclk
#      connect_bd_net [get_bd_pins $offset/RST_N] $design_p_arstn
#      connect_bd_intf_net $s [get_bd_intf_pins $offset/S_AXI]
#      set bic [tapasco::ip::create_axi_ic "${n}_offset_ic" 1 1]
#      connect_bd_intf_net [get_bd_intf_pins $bic/S00_AXI] [get_bd_intf_pin $offset/M_AXI]
#      lappend mem_offsets [get_bd_intf_pin $bic/M00_AXI]
#      connect_bd_net $mem_aclk \
#        [get_bd_pins -of_objects $bic -filter { TYPE == clk && DIR == I && NAME !~ "S00_ACLK"}]
#      connect_bd_net $design_aclk \
#        [get_bd_pins -of_objects $bic -filter { TYPE == clk && DIR == I && NAME =~ "S00_ACLK"}]
#
#      connect_bd_net $mem_ic_arstn \
#        [get_bd_pins -of_objects $bic -filter { TYPE == rst && DIR == I && NAME =~ "ARESETN" }]
#
#      connect_bd_net $mem_p_arstn \
#        [get_bd_pins -of_objects $bic -filter { TYPE == rst && DIR == I && NAME =~ "M00_ARESETN" }]
#
#      connect_bd_net $design_p_arstn \
#        [get_bd_pins -of_objects $bic -filter { TYPE == rst && DIR == I && NAME =~ "S00_ARESETN" }]
#    }
#
#
#    # generate PS MPSoC instance. Default values are fine
#    set ps [tapasco::ip::create_ultra_ps "zynqmp" [tapasco::get_board_preset] [tapasco::get_design_frequency]]
#
#    puts "  PS generated..."
#    puts "  PS configuration ..."
#
#    # activate ACP, HPC0, HP2 and GP0/1 (+ FCLK1 @10MHz)
#    set_property -dict [list \
#      CONFIG.PSU__FPGA_PL1_ENABLE {1} \
#      CONFIG.PSU__USE__S_AXI_GP0 {1}  \
#      CONFIG.PSU__USE__S_AXI_GP2 {0}  \
#      CONFIG.PSU__USE__S_AXI_GP4 {1}  \
#      CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ [tapasco::get_design_frequency] \
#      CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {10} \
#      CONFIG.PSU__USE__IRQ0 {1} \
#      CONFIG.PSU__USE__IRQ1 {1} \
#      CONFIG.PSU__HIGH_ADDRESS__ENABLE {1} \
#      CONFIG.PSU__USE__M_AXI_GP0 {1} \
#      CONFIG.PSU__USE__M_AXI_GP1 {1} \
#      CONFIG.PSU__USE__M_AXI_GP2 {0}
#      ] $ps
#    puts "  PS configuration finished"
#
#    # connect masters
#    connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_HPM0_FPD"] [get_bd_intf_pins -of_objects $gp0_ic_tree -filter { MODE == Slave }]
#    connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_HPM1_FPD"] [get_bd_intf_pins -of_objects $gp1_ic_tree -filter { MODE == Slave }]
#
#    # connect slaves
#    set ps_mem_slaves [list \
#      [get_bd_intf_pins "$ps/S_AXI_HPC0_FPD"] \
#      [get_bd_intf_pins "$ps/S_AXI_HP2_FPD"]
#    ]
#    foreach ms $mem_offsets pms $ps_mem_slaves { connect_bd_intf_net $ms $pms }
#
#    # configure AxPROT + AxCACHE signals of HPC0 port for coherent memory accesses
#    set constant_HPC0_prot [tapasco::ip::create_constant constant_HPC0_prot 3 2]
#    connect_bd_net [get_bd_pins $ps/saxigp0_awprot] [get_bd_pins constant_HPC0_prot/dout]
#    connect_bd_net [get_bd_pins $ps/saxigp0_arprot] [get_bd_pins constant_HPC0_prot/dout]
#    set constant_HPC0_cache [tapasco::ip::create_constant constant_HPC0_cache 4 15]
#    connect_bd_net [get_bd_pins $ps/saxigp0_awcache] [get_bd_pins constant_HPC0_cache/dout]
#    connect_bd_net [get_bd_pins $ps/saxigp0_arcache] [get_bd_pins constant_HPC0_cache/dout]
#
#    # connect interrupt
#    set irq_top [tapasco::ip::create_xlslice irq_top 16 0]
#    set_property -dict [list CONFIG.DIN_FROM {7} CONFIG.DIN_WIDTH {16} CONFIG.DOUT_WIDTH {8} CONFIG.DIN_TO {0}] $irq_top
#    connect_bd_net [get_bd_pins $irq_0] [get_bd_pins $irq_top/Din]
#    connect_bd_net [get_bd_pins $irq_top/Dout] [get_bd_pins $ps/pl_ps_irq0]
#    set irq_bot [tapasco::ip::create_xlslice irq_bot 16 0]
#    set_property -dict [list CONFIG.DIN_FROM {15} CONFIG.DIN_WIDTH {16} CONFIG.DOUT_WIDTH {8} CONFIG.DIN_TO {8}] $irq_bot
#    connect_bd_net [get_bd_pins $irq_0] [get_bd_pins $irq_bot/Din]
#    connect_bd_net [get_bd_pins $irq_bot/Dout] [get_bd_pins $ps/pl_ps_irq1]
#
#    # connect reset
#    connect_bd_net [get_bd_pins "$ps/pl_resetn0"] $reset_in
#
#    # connect output clock if needed
#    if {[info exists ps_clk_in]} {
#      connect_bd_net [get_bd_pins "$ps/pl_clk0"] $ps_clk_in
#    }
#
#    # connect memory slaves to memory clock and reset
#    connect_bd_net $mem_aclk [get_bd_pins -of_objects $ps -filter {NAME =~ "s*hp*aclk"}]
#
#    # connect clocks
#    # Host side
#    connect_bd_net $host_aclk \
#      [get_bd_pins -of_objects $ps -filter { TYPE == clk && DIR == I && NAME !~ "s*hp*aclk"}]
#    connect_bd_net $host_aclk \
#      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == clk && DIR == I && NAME =~ "s_aclk"}]
#    connect_bd_net $host_aclk \
#      [get_bd_pins -of_objects $gp1_ic_tree -filter { TYPE == clk && DIR == I && NAME =~ "m_aclk"}]
#
#    connect_bd_net $host_ic_arstn \
#      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == rst && DIR == I && NAME =~ "s_interconnect*" }]
#    connect_bd_net $host_p_arstn \
#      [get_bd_pins -of_objects [list $gp0_ic_tree $gp1_ic_tree] -filter { TYPE == rst && DIR == I && NAME =~ "s_peripheral*" }]
#
#    connect_bd_net $host_ic_arstn \
#      [get_bd_pins -of_objects $gp1_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_interconnect*" }]
#    connect_bd_net $host_p_arstn \
#      [get_bd_pins -of_objects $gp1_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_peripheral*" }]
#
#    # Design side
#    connect_bd_net $design_aclk \
#      [get_bd_pins -of_objects [list $gp0_ic_tree] -filter { TYPE == clk && DIR == I && NAME =~ "m_aclk"}]
#
#    connect_bd_net $design_ic_arstn \
#      [get_bd_pins -of_objects $gp0_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_interconnect*" }]
#    connect_bd_net $design_p_arstn \
#      [get_bd_pins -of_objects $gp0_ic_tree -filter { TYPE == rst && DIR == I && NAME =~ "m_peripheral*" }]
#
# todo: maybe instantiate some axi smart connects here, needs adjustment of address mapping method
      save_bd_design

  }
}
