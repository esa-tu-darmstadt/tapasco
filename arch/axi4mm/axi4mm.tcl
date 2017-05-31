#
# Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
# @file		axi4mm.tcl
# @brief	AXI4 memory mapped master/slave interface based Architectures.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
#
namespace eval arch {
  namespace export create
  namespace export get_irqs
  namespace export get_masters
  namespace export get_processing_elements
  namespace export get_slaves

  set arch_mem_ics [list]
  set arch_mem_ports [list]
  set arch_host_ics [list]
  set arch_irq_concats [list]

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/arch/axi4mm/plugins" "*.tcl"] {
    source -notrace $f
  }

  # Returns a list of the bd_cells of slave interfaces of the threadpool.
  proc get_slaves {} {
    set inst [current_bd_instance]
    current_bd_instance "uArch"
    set r [list [get_bd_intf_pins -of [get_bd_cells "in1"] -filter { MODE == "Slave" }]]
    current_bd_instance $inst
    return $r
  }

  # Returns a list of the bd_cells of master interfaces of the threadpool.
  proc get_masters {} {
    variable arch_mem_ports
    return $arch_mem_ports
  }

  proc get_processing_elements {} {
    return [get_bd_cells "uArch/target*"]
  }

  # Returns a list of interrupt lines from the threadpool.
  proc get_irqs {} {
    return [get_bd_pins -of_objects [get_bd_cells "uArch"] -filter {TYPE == "intr" && DIR == "O"}]
  }

  # Checks, if the current composition can be instantiated. Exits script with
  # error message otherwise.
  proc arch_check_instance_count {kernels} {
    set totalInst 0
    set mc 0
    set sc 0
    dict for {k v} $kernels {
      # add count to total instances
      set no [dict get $kernels $k count]
      set totalInst [expr "$totalInst + $no"]
      # get first instance
      set example [get_bd_cells [format "target_ip_%02d_000" $k]]
      # add masters and slaves to total count
      set masterc [llength [get_bd_intf_pins -of $example -filter { MODE == "Master" && CONFIG.PROTOCOL =~ "AXI*" }]]
      set slavec  [llength [get_bd_intf_pins -of $example -filter { MODE == "Slave" && CONFIG.PROTOCOL =~ "AXI*" }]]
      set mc [expr "$mc + ($no * $masterc)"]
      set sc [expr "$sc + ($no * $slavec)"]
    }
    if {$totalInst > 128} {
      error "ERROR: Currently only 128 instances of target IP are supported."
      exit 1
    }
    set max_masters [expr [join [platform::max_masters] +]]
    if {$mc > $max_masters} {
      puts "ERROR: Configuration requires connection of $mc M-AXI interfaces, but the Platform supports only $max_masters."
      exit 1
    }
    if {$sc > 128} {
      puts "ERROR: Configuration requires connection of $sc S-AXI interfaces; at the moment only 128 are supported."
      exit 1
    }
  }

  # Instantiates all IP cores in the composition and return an array with their
  # bd_cells.
  proc arch_create_instances {composition} {
    set insts [list]

    set no_kinds [llength [dict keys $composition]]
    puts "Creating $no_kinds different IP cores ..."

    for {set i 0} {$i < $no_kinds} {incr i} {
      set no_inst [dict get $composition $i count]
      set vlnv [dict get $composition $i vlnv]
      puts "Creating $no_inst instances of target IP core ..."
      puts "  VLNV: $vlnv"
      for {set j 0} {$j < $no_inst} {incr j} {
        set name [format "target_ip_%02d_%03d" $i $j]
        set inst [lindex [tapasco::call_plugins "post-pe-create" [create_bd_cell -type ip -vlnv "$vlnv" $name]] 0]
        lappend insts $inst
      }
    }
    puts "insts = $insts"
    return $insts
  }

  # Instantiates the memory interconnect hierarchy.
  proc arch_create_mem_interconnects {composition outs} {
    variable arch_mem_ports
    set no_kinds [llength [dict keys $composition]]
    set ic_m 0
    set m32 0
    set m64 0

    # determine number of masters from composition
    for {set i 0} {$i < $no_kinds} {incr i} {
      set no_inst [dict get $composition $i count]
      set example [get_bd_cells [format "target_ip_%02d_000" $i]]
      set masters [tapasco::get_aximm_interfaces $example]
      set ic_m [expr "$ic_m + [llength $masters] * $no_inst"]

      set masters_32b [get_bd_intf_pins -of_objects $example -filter { MODE == "Master" && VLNV == "xilinx.com:interface:aximm_rtl:1.0" && CONFIG.DATA_WIDTH == 32 }]
      set masters_64b [get_bd_intf_pins -of_objects $example -filter { MODE == "Master" && VLNV == "xilinx.com:interface:aximm_rtl:1.0" && CONFIG.DATA_WIDTH == 64 }]
      set m32 [expr "$m32 + [llength $masters_32b] * $no_inst"]
      set m64 [expr "$m64 + [llength $masters_64b] * $no_inst"]
    }

    puts "  Found a total of $m32 32b masters and $m64 64b masters."
    if {$m32 > 0 && $m64 > 0} {
      error "  Design contains mixed bitwidth masters, not supported!"
    }
    set no_masters [expr "max(max($m32, $m64), [expr $no_inst * [llength $masters]])"]
    puts "  no_masters : $masters"

    # check if all masters can be connected with the outs config
    set total_ports [expr [join $outs +]]
    if {$total_ports < $no_masters} {
      error "  ERROR: can only connect up to $total_ports masters"
    } {
      puts "  total available ports: $total_ports"
    }

    # create ports and interconnect trees
    set ic_ports [list]
    set mdist [list]
    for {set i 0} {$i < [llength $outs] && $i < $no_masters} {incr i} {
      lappend ic_ports [create_bd_intf_pin -mode Master -vlnv "xilinx.com:interface:aximm_rtl:1.0" [format "M_AXI_MEM_%02d" $i]]
      lappend mdist 0
    }

    # distribute masters round-robin on all output ports: mdist holds 
    # number of masters for each port
    set j 0
    for {set i 0} {$i < $no_masters} {incr i} {
      lset mdist $j [expr "[lindex $mdist $j] + 1"]
      incr j
      if {$j >= [llength $mdist]} { set j 0 }
      if {$i + 1 < $no_masters} {
        # find new port with capacity
        while {[lindex $mdist $j] == [lindex $outs $j]} {
          incr j
          if {$j >= [llength $mdist]} { set j 0 }
        }
      }
    }

    # generate output trees
    for {set i 0} {$i < [llength $mdist]} {incr i} {
      puts "  mdist[$i] = [lindex $mdist $i]"
      set out [tapasco::create_interconnect_tree "out_$i" [lindex $mdist $i]]
      connect_bd_intf_net [get_bd_intf_pins -filter {MODE == Master && VLNV == "xilinx.com:interface:aximm_rtl:1.0"} -of_objects $out] [lindex $ic_ports $i]
    }

    set arch_mem_ports $ic_ports
  }

  # Instantiates the host interconnect hierarchy.
  proc arch_create_host_interconnects {composition {no_slaves 1}} {
    set no_kinds [llength [dict keys $composition]]
    set ic_s 0

    for {set i 0} {$i < $no_kinds} {incr i} {
      set no_inst [dict get $composition $i count]
      set example [get_bd_cells [format "target_ip_%02d_000" $i]]
      set slaves  [get_bd_intf_pins -of $example -filter { MODE == "Slave" && VLNV == "xilinx.com:interface:aximm_rtl:1.0" }]
      set ic_s [expr "$ic_s + [llength $slaves] * $no_inst"]
    }
    set in1 [tapasco::create_interconnect_tree "in1" $ic_s false]

    puts "Creating interconnects toward peripherals ..."
    puts "  $ic_s slaves to connect to host"

    set out_port [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI]
    connect_bd_intf_net $out_port [get_bd_intf_pins -of_objects $in1 -filter {NAME == "S000_AXI"}]

    return $in1
  }

  # Connects the host interconnects to the threadpool.
  proc arch_connect_host {periph_ics ips} {
    puts "Connecting PS to peripherals ..."
    puts "  periph_ics = $periph_ics"
    puts "  ips = $ips"

    set pic 0
    set ic [lindex $periph_ics $pic]
    set conn 0

    set ms [get_bd_intf_pins -of_objects $periph_ics -filter {MODE == "Master" && VLNV == "xilinx.com:interface:aximm_rtl:1.0"}]
    set ss [get_bd_intf_pins -of_objects $ips -filter {MODE == "Slave" && VLNV == "xilinx.com:interface:aximm_rtl:1.0"}]

    puts "  ms = $ms"
    puts "  ss = $ss"

    if {[llength $ms] != [llength $ss]} {
      error "master slave count mismatch ([llength $ms]/[llength $ss])"
    }

    for {set i 0} {$i < [llength $ms]} {incr i} {
      connect_bd_intf_net [lindex $ms $i] [lindex $ss $i]
    }
    return

    foreach ip $ips {
      # connect target IP slaves
      set slaves [get_bd_intf_pins -of $ip -filter { MODE == "Slave" && VLNV == "xilinx.com:interface:aximm_rtl:1.0"}]
      foreach slave $slaves {
        set m_name [format "axi_periph_ic_$pic/M%02d_AXI" $conn]
        connect_bd_intf_net [get_bd_intf_pins $m_name] -boundary_type upper $slave
        incr conn
      }
      if {$conn == 16} { incr pic; set ic [lindex $periph_ics $pic]; set conn 0 }
    }
  }

  # Connects the threadpool to memory interconnects.
  proc arch_connect_mem {mem_ics ips} {
    # get PE masters
    set masters [lsort -dictionary [tapasco::get_aximm_interfaces $ips]]
    # interleave slaves of out ic trees
    set outs [get_bd_cells -filter {NAME =~ "out_*"}]
    set sc [llength [tapasco::get_aximm_interfaces $outs "Slave"]]
    set tmp [list]
    foreach out $outs { lappend tmp [tapasco::get_aximm_interfaces $out "Slave"] }
    set outs $tmp
    set slaves [list]
    set j 0
    for {set i 0} {$i < $sc} {incr i} {
      # skip outs without slaves
      while {[llength [lindex $outs $j]] == 0} {
        incr j
        set j [expr "$j % [llength $outs]"]
      }
      # remove slave from current out
      set slave [lindex [lindex $outs $j] end]
      set outs [lreplace $outs $j $j [lreplace [lindex $outs $j] end end]]
      lappend slaves $slave
      # next out
      incr j
      set j [expr "$j % [llength $outs]"]
    }

    puts "Connecting memory interconnect topology ... "
    puts "  Number of masters: [llength $masters]"
    puts "  Masters in order : $masters"
    puts "  Number of slaves: [llength $slaves]"
    puts "  Slaves in order : $slaves"

    if {[llength $masters] != [llength $slaves]} {
      error "  ERROR: Mismatch between #slaves and #masters - probably a BUG"
    }

    # simply connect masters to output slaves
    for {set i 0} {$i < [llength $masters]} {incr i} {
      connect_bd_intf_net [lindex $masters $i] [lindex $slaves $i]
    }
  }

  # Connects the architecture interrupt lines.
  proc arch_connect_interrupts {ips} {
    variable arch_irq_concats
    puts "Connecting [llength $ips] target IP interrupts ..."

    set i 0
    set j 0
    set left [llength $ips]
    set cc [tapasco::createConcat "xlconcat_$j" [expr "[llength $ips] > 32 ? 32 : [llength $ips]"]]
    lappend arch_irq_concats $cc
    foreach ip [lsort $ips] {
      foreach pin [get_bd_pins -of $ip -filter { TYPE == intr }] {
        connect_bd_net $pin [get_bd_pins -of $cc -filter "NAME == In$i"]
        incr i
        incr left -1
        if {$i > 31} {
          set i 0
  	incr j
  	if { $left > 0 } {
  	  set cc [tapasco::createConcat "xlconcat_$j" [expr "$left > 32 ? 32 : $left"]]
  	  lappend arch_irq_concats $cc
  	}
        }
      }
    }
    set i 0
    foreach irq_concat $arch_irq_concats {
      # create hierarchical port with correct width
      set port [get_bd_pins -of_objects $irq_concat -filter {DIR == "O"}]
      set out_port [create_bd_pin -type INTR -dir O -from [get_property LEFT $port] -to [get_property RIGHT $port] "irq_$i"]
      connect_bd_net $port $out_port
      incr i
    }
  }

  # Connect internal clock lines.
  proc arch_connect_clocks {} {
    set host_aclk [create_bd_pin -type clk -dir I "host_aclk"]
    connect_bd_net $host_aclk [get_bd_pins -filter { NAME == "s_aclk" } -of_objects [get_bd_cells -filter {NAME =~ "in*"}]]
    set design_aclk [create_bd_pin -type clk -dir I "design_aclk"]
    connect_bd_net $design_aclk [get_bd_pins -filter { NAME == "m_aclk" } -of_objects [get_bd_cells -filter {NAME =~ "in*"}]]
    connect_bd_net $design_aclk [get_bd_pins -filter { TYPE == clk && DIR == I } -of_objects [get_bd_cells -filter {NAME =~ "target_ip_*"}]]
    puts "  creating clock lines ..."
    set memory_aclk [create_bd_pin -type clk -dir I "memory_aclk"]
    if {[llength [get_bd_cells -filter {NAME =~ "out*"}]] > 0} {
      connect_bd_net $design_aclk [get_bd_pins -filter { NAME == "s_aclk" } -of_objects [get_bd_cells -filter {NAME =~ "out*"}]]
      connect_bd_net $memory_aclk [get_bd_pins -filter { NAME == "m_aclk" } -of_objects [get_bd_cells -filter {NAME =~ "out*"}]]
    }
  }

  # Connect internal reset lines.
  proc arch_connect_resets {} {
   # create hierarchical ports for host interconnect and peripheral resets
   set host_ic_arstn [create_bd_pin -type rst -dir I "host_interconnect_aresetn"]
   set host_p_arstn  [create_bd_pin -type rst -dir I "host_peripheral_aresetn"]
   connect_bd_net $host_ic_arstn [get_bd_pins -filter { NAME == "s_interconnect_aresetn" } -of_objects [get_bd_cells -filter {NAME =~ "in*"}]]
   connect_bd_net $host_p_arstn [get_bd_pins -filter { NAME == "s_peripheral_aresetn" } -of_objects [get_bd_cells -filter {NAME =~ "in*"}]]

   # create hierarchical ports for design interconnect and peripheral resets
   set design_ic_arstn [create_bd_pin -type rst -dir I "design_interconnect_aresetn"]
   set design_p_arstn  [create_bd_pin -type rst -dir I "design_peripheral_aresetn"]
   connect_bd_net $design_ic_arstn [get_bd_pins -filter { NAME == "m_interconnect_aresetn" } -of_objects [get_bd_cells -filter {NAME =~ "in*"}]]
   connect_bd_net $design_p_arstn [get_bd_pins -filter { NAME == "m_peripheral_aresetn" } -of_objects [get_bd_cells -filter {NAME =~ "in*"}]]
   connect_bd_net $design_p_arstn [get_bd_pins -filter { TYPE == rst && DIR == I } -of_objects [get_bd_cells -filter {NAME =~ "target_ip*"}]]

   # create hierarchical ports for memory interconnect and peripheral resets
   set memory_ic_arstn [create_bd_pin -type rst -dir I "memory_interconnect_aresetn"]
   set memory_p_arstn  [create_bd_pin -type rst -dir I "memory_peripheral_aresetn"]
   if {[llength [get_bd_cells -filter {NAME =~ "out*"}]] > 0} {
     set outs [get_bd_cells -filter {NAME =~ "out*"}]
     connect_bd_net $design_ic_arstn [get_bd_pins -filter { NAME == "s_interconnect_aresetn" } -of_objects $outs]
     connect_bd_net $design_p_arstn [get_bd_pins -filter { NAME == "s_peripheral_aresetn" } -of_objects $outs]
     connect_bd_net $memory_ic_arstn [get_bd_pins -filter { NAME == "m_interconnect_aresetn" } -of_objects $outs]
     connect_bd_net $memory_p_arstn [get_bd_pins -filter { NAME == "m_peripheral_aresetn" } -of_objects $outs]
   }
  }

  # Instantiates the architecture.
  proc create {{mgroups 0}} {
    variable arch_mem_ics
    variable arch_host_ics

    if {$mgroups == 0} {
      set mgroups [platform::max_masters]
    }

    # create hierarchical group
    set group [create_bd_cell -type hier "uArch"]
    set instance [current_bd_instance .]
    current_bd_instance $group

    # create instances of target IP
    set kernels [tapasco::get_composition]
    set insts [arch_create_instances $kernels]
    arch_check_instance_count $kernels
    set arch_mem_ics [arch_create_mem_interconnects $kernels $mgroups]
    set arch_host_ics [arch_create_host_interconnects $kernels]

    # connect AXI infrastructure
    arch_connect_host $arch_host_ics $insts
    arch_connect_mem $arch_mem_ics $insts

    set no_inst 0
    for {set i 0} {$i < [llength [dict keys $kernels]]} {incr i} { set no_inst [expr "$no_inst + [dict get $kernels $i count]"] }
    arch_connect_interrupts $insts

    arch_connect_clocks
    arch_connect_resets

    # exit the hierarchical group
    current_bd_instance $instance
  }
}
