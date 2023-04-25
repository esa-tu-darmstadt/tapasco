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

namespace eval arch {
  namespace export create
  namespace export get_masters
  namespace export get_processing_elements
  namespace export get_slaves

  set arch_mem_ics [list]
  set arch_mem_ports [list]
  set arch_host_ics [list]

  # scan plugin directory
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/arch/axi4mm/plugins" "*.tcl"] {
    source -notrace $f
  }

  # Returns a list of the bd_cells of slave interfaces of the threadpool.
  proc get_slaves {} {
    set inst [current_bd_instance]
    current_bd_instance [::tapasco::subsystem::get arch]
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
    return [get_bd_cells -of_objects [::tapasco::subsystem::get arch] -filter { NAME =~ target*}]
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
    if {$totalInst > [::tapasco::get_platform_num_slots]} {
      error "ERROR: Currently only [::tapasco::get_platform_num_slots] instances of target IP are supported."
      exit 1
    }
    set max_masters [expr [join [platform::max_masters] +]]
    if {$mc > $max_masters} {
      puts "ERROR: Configuration requires connection of $mc M-AXI interfaces, but the Platform supports only $max_masters."
      exit 1
    }
    if {$sc > [::tapasco::get_platform_num_slots]} {
      puts "ERROR: Configuration requires connection of $sc S-AXI interfaces; at the moment only [::tapasco::get_platform_num_slots] are supported."
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
        # Create PE instance
        set name [format "target_ip_%02d_%03d" $i $j]
        set inst [create_bd_cell -type ip -vlnv "$vlnv" "internal_$name"]

        # Only create a wrapper around PEs if atleast one plugin is present
        if {[llength [tapasco::get_plugins "post-pe-create"]] > 0} {
          set bd_inst [current_bd_instance .]
          set group [create_wrapper_around_pe $inst $name]

          set inst [lindex [tapasco::call_plugins "post-pe-create" $inst] 0]
          # Return to the same block design instance as before
          current_bd_instance $bd_inst

          # return the wrapper so that it can be connected
          lappend insts $group
        } else {
          lappend insts $inst
        }
      }
    }
    puts "insts = $insts"
    return $insts
  }

  # Create a wrapper around a PE to embed plugins
  proc create_wrapper_around_pe {inst name} {
    # create group, move instance into group
    set group [create_bd_cell -type hier $name]
    move_bd_cells $group $inst

    current_bd_instance $group
    set bd_inst [current_bd_instance .]

    # bypass existing AXI4Lite slaves
    set lite_ports [list]
    set lites [get_bd_intf_pins -of_objects $inst -filter {MODE == Slave && CONFIG.PROTOCOL == AXI4LITE}]
    foreach ls $lites {
      set op [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Slave [get_property NAME $ls]]
      connect_bd_intf_net $op $ls
      lappend lite_ports $ls
    }
    puts "lite_ports = $lite_ports"

    # create master ports
    set maxi_ports [list]
    foreach mp [get_bd_intf_pins -of_objects $inst -filter {MODE == Master && (CONFIG.PROTOCOL == AXI4 || CONFIG.PROTOCOL == AXI3)}] {
      set op [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Master [get_property NAME $mp]]
      connect_bd_intf_net $mp $op
      lappend maxi_ports $mp
    }
    puts "maxi_ports = $maxi_ports"

    # create interrupt port
    foreach interrupt [get_bd_pins -of_objects $inst -filter {TYPE == intr}] {
      connect_bd_net $interrupt [create_bd_pin -type intr -dir O [get_property NAME $interrupt]]
    }

    return $group
  }

  # Retrieve AXI-MM interfaces of given instance of kernel kind and mode.
  proc get_aximm_interfaces {kind inst {mode "Master"}} {
    set name [format "target_ip_%02d_%03d" $kind $inst]
    puts "Retrieving list of slave interfaces for $name ..."
    return [tapasco::get_aximm_interfaces [get_bd_cell -hier -filter "NAME == $name"] $mode]
  }

  # Determines the number of AXI-MM interfaces in the composition
  proc arch_get_num_masters {composition} {
    set no_kinds [llength [dict keys $composition]]
    set m_total 0

    # determine number of masters from composition
    for {set i 0} {$i < $no_kinds} {incr i} {
      set no_inst [dict get $composition $i count]
      set example [get_bd_cells [format "target_ip_%02d_000" $i]]
      set masters [tapasco::get_aximm_interfaces $example]
      set m_total [expr "$m_total + [llength $masters] * $no_inst"]
    }

    puts "  Found a total of $m_total masters."
    set no_masters $m_total
    puts "  no_masters : $no_masters"

    return $no_masters
  }

  # Instantiates a memory interconnect hierarchy for the given number of masters
  proc arch_create_mem_interconnects {outs no_masters} {
    variable arch_mem_ports


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
      lappend ic_ports [create_bd_intf_pin -mode Master -vlnv "xilinx.com:interface:aximm_rtl:1.0" [format "M_MEM_%d" $i]]
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
      if {[tapasco::is_versal]} {
        set out [tapasco::create_smartconnect_tree "out_$i" [lindex $mdist $i]]
      } else {
        set out [tapasco::create_interconnect_tree "out_$i" [lindex $mdist $i]]
      }
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

    set out_port [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_ARCH"]

    if {$ic_s == 1} {
      puts "Connecting one slave to host"
      return $out_port
    } {
      if {[tapasco::is_versal]} {
        set in1 [tapasco::create_smartconnect_tree "in1" $ic_s false]
      } else {
        set in1 [tapasco::create_interconnect_tree "in1" $ic_s false]
      }

      puts "Creating interconnects toward peripherals ..."
      puts "  $ic_s slaves to connect to host"

      connect_bd_intf_net $out_port [get_bd_intf_pins -of_objects $in1 -filter {NAME == "S000_AXI"}]
    }

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
    if {[llength $ms] == 0 && [get_property CLASS $periph_ics] == "bd_intf_pin"} {
      set ms $periph_ics
    }
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
  proc arch_connect_mem {mem_ics masters} {
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
    puts "Connecting [llength $ips] target IP interrupts ..."

    set i 0
    set num_slaves [llength [tapasco::get_aximm_interfaces $ips "Slave"]]
    set left $num_slaves
    puts "  total number of slave interfaces: $num_slaves"

    # Only one Interrupt per IP is connected
    foreach ip [lsort $ips] {

      set pe_sub_interrupt 0

      foreach pin [get_bd_pins -of $ip -filter { TYPE == intr }] {
          set intr_name "PE_${i}_${pe_sub_interrupt}"
          puts "Creating interrupt $intr_name"
          connect_bd_net $pin [::tapasco::ip::add_interrupt $intr_name "design"]
          incr pe_sub_interrupt
      }
      incr i
    }
  }

  # Connect internal clock lines.
  proc arch_connect_clocks {} {
    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] \
      [get_bd_pins -of_objects [get_bd_cells] -filter "TYPE == clk && DIR == I"] \
      [get_bd_pins -of_objects [get_bd_cells -hier -filter {PATH =~ "*target_ip*"}] -filter "TYPE == clk && DIR == I"]
  }

  # Connect internal reset lines.
  proc arch_connect_resets {} {
    connect_bd_net -quiet [tapasco::subsystem::get_port "design" "rst" "interconnect"] \
      [get_bd_pins -of_objects [get_bd_cells] -filter "TYPE == rst && NAME =~ *interconnect_aresetn && DIR == I"]
    connect_bd_net [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"] \
      [get_bd_pins -of_objects [get_bd_cells -of_objects [current_bd_instance .]] -filter "TYPE == rst && NAME =~ *peripheral_aresetn && DIR == I"] \
      [get_bd_pins -filter { TYPE == rst && DIR == I && CONFIG.POLARITY != ACTIVE_HIGH } -of_objects [get_bd_cells -hier -filter {PATH =~ "*target_ip*"}]]
    set active_high_resets [get_bd_pins -of_objects [get_bd_cells -hier] -filter "TYPE == rst && DIR == I && CONFIG.POLARITY == ACTIVE_HIGH"]
    if {[llength $active_high_resets] > 0} {
      connect_bd_net [tapasco::subsystem::get_port "design" "rst" "peripheral" "reset"] $active_high_resets
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
    set group [tapasco::subsystem::create "arch"]
    set instance [current_bd_instance .]
    current_bd_instance $group

    # create instances of target IP
    set kernels [tapasco::get_composition]
    set insts [arch_create_instances $kernels]

    set no_inst 0
    for {set i 0} {$i < [llength [dict keys $kernels]]} {incr i} { set no_inst [expr "$no_inst + [dict get $kernels $i count]"] }
    arch_connect_interrupts $insts

    arch_check_instance_count $kernels
    set no_masters [arch_get_num_masters $kernels]
    set arch_mem_ics [arch_create_mem_interconnects $mgroups $no_masters]

    set arch_host_ics [arch_create_host_interconnects $kernels 1]

    # connect AXI infrastructure
    arch_connect_host $arch_host_ics $insts

    set masters [lsort -dictionary [tapasco::get_aximm_interfaces $insts]]
    arch_connect_mem $arch_mem_ics $masters

    arch_connect_clocks
    arch_connect_resets

    # exit the hierarchical group
    current_bd_instance $instance
  }
}
