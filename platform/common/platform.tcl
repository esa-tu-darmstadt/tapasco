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
# @file		platform.tcl
# @brief	Platform skeleton implementations.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
#
namespace eval platform {
  namespace export create
  namespace export generate
  namespace export get_address_map
  source "$::env(TAPASCO_HOME)/platform/common/addressmap.tcl"

  # Creates the platform infrastructure, consisting of a number of subsystems.
  # Subsystems "host", "clocks_and_resets", "memory", "intc" and "tapasco" are
  # mandatory, their wiring pre-defined. Custom subsystems can be instantiated
  # by implementing a "create_custom_subsystem_<NAME>" proc in platform::, where
  # <NAME> is a placeholder for the name of the subsystem.
  proc create {} {
    set instance [current_bd_instance]
    # create mandatory subsystems
    set ss_host    [tapasco::subsystem::create "host"]
    set ss_cnrs    [tapasco::subsystem::create "clocks_and_resets" true]
    set ss_mem     [tapasco::subsystem::create "memory"]
    set ss_intc    [tapasco::subsystem::create "intc"]
    set ss_tapasco [tapasco::subsystem::create "tapasco"]

    set sss [list $ss_cnrs $ss_host $ss_intc $ss_mem $ss_tapasco]

    foreach ss $sss {
      set name [string trim $ss "/"]
      set cmd  "create_subsystem_$name"
      puts "Creating subsystem $name ..."
      if {[llength [info commands $cmd]] == 0} {
        error "Platform does not implement mandatory command $cmd!"
      }
      current_bd_instance $ss
      eval $cmd
      current_bd_instance $instance
      puts "Subsystem $name complete."
    }

    # create custom subsystems
    foreach ss [info commands create_custom_subsystem_*] {
      set name [regsub {.*create_custom_subsystem_(.*)} $ss {\1}]
      puts "Creating custom subsystem $name ..."
      current_bd_instance [tapasco::subsystem::create $name]
      eval $ss
      current_bd_instance $instance
    }

    wire_subsystem_wires
    wire_subsystem_intfs
    addressmap::construct_address_map
    update_status_core

    tapasco::call_plugins "post-platform"
  }

  proc update_status_core {} {
    set inst [current_bd_instance]
    current_bd_instance [tapasco::subsystem::get tapasco]
    file delete -force "[get_property DIRECTORY [current_project]]/../user_ip/tapasco-status"
    set status [get_bd_cells -filter "VLNV == [tapasco::ip::get_vlnv tapasco_status]"]
    replace_bd_cell -preserve_name -preserve_configuration $status [tapasco::ip::create_tapasco_status "tapasco_status2"]
    delete_bd_objs $status
    current_bd_instance $inst
  }

  proc connect_subsystems {} {
    foreach s {host design mem} {
      connect_bd_net [get_bd_pins -of_objects [get_bd_cells] -filter "NAME == ${s}_clk && DIR == O"] \
        [get_bd_pins -of_objects [get_bd_cells] -filter "NAME =~ ${s}_clk && DIR == I"]
      connect_bd_net [get_bd_pins -of_objects [get_bd_cells] -filter "NAME == ${s}_interconnect_resetn && DIR == O"] \
        [get_bd_pins -of_objects [get_bd_cells] -filter "NAME =~ ${s}_interconnect_resetn && DIR == I"] \
      connect_bd_net [get_bd_pins -of_objects [get_bd_cells] -filter "NAME == ${s}_peripheral_resetn && DIR == O"] \
        [get_bd_pins -of_objects [get_bd_cells] -filter "NAME =~ ${s}_peripheral_resetn && DIR == I"] \
      connect_bd_net [get_bd_pins -of_objects [get_bd_cells] -filter "NAME == ${s}_peripheral_reset && DIR == O"] \
        [get_bd_pins -of_objects [get_bd_cells] -filter "NAME =~ ${s}_peripheral_resetn && DIR == O"] \
    }
  }

  proc create_subsystem_tapasco {} {
    puts "  creating slave port S_TAPASCO ..."
    set port [create_bd_intf_pin -vlnv [tapasco::ip::get_vlnv "aximm_intf"] -mode Slave "S_TAPASCO"]
    puts "  instantiating custom status core ..."
    set tapasco_status [tapasco::ip::create_tapasco_status "tapasco_status"]
    update_ip_catalog -rebuild
    puts "  wiring ..."
    connect_bd_intf_net $port [get_bd_intf_pins -of_objects $tapasco_status -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]
    connect_bd_net [tapasco::subsystem::get_port "design" "clk"] [get_bd_pins -of_objects $tapasco_status -filter {TYPE == clk && DIR == I}]
    connect_bd_net [tapasco::subsystem::get_port "design" "rst" "peripheral" "reset"] [get_bd_pins -of_objects $tapasco_status -filter {TYPE == rst && DIR == I}]
    puts "  done!"
  }

  proc wire_subsystem_wires {} {
    foreach p [get_bd_pins -quiet -of_objects [get_bd_cells] -filter {INTF == false && DIR == I}] {
      if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        set name [get_property NAME $p]
        set type [get_property TYPE $p]
        puts "Looking for matching source for $p ($name) with type $type ..."
        set src [lsort [get_bd_pins -quiet -of_objects [get_bd_cells] -filter "NAME == $name && TYPE == $type && INTF == false && DIR == O"]]
        if {[llength $src] > 0} {
          puts "  found pin: $src, connecting $p -> $src"
          connect_bd_net $src $p
        } else {
          puts "  found no matching pin for $p"
        }
      }
    }
  }

  proc wire_subsystem_intfs {} {
    foreach p [get_bd_intf_pins -quiet -of_objects [get_bd_cells] -filter {MODE == Slave}] {
      if {[llength [get_bd_intf_nets -quiet -of_objects $p]] == 0} {
        set name [regsub {^S_} [get_property NAME $p] {M_}]
        set vlnv [get_property VLNV $p]
        puts "Looking for matching source for $p ($name) with VLNV $vlnv ..."
        set srcs [lsort [get_bd_intf_pins -quiet -of_objects [get_bd_cells] -filter "NAME == $name && VLNV == $vlnv && MODE == Master"]]
        foreach src $srcs {
          if {[llength [get_bd_intf_nets -quiet -of_objects $src]] == 0} {
            set netname [format "%s_net" [string trim [string map {"/" "_"} "$src"] "_"]]
            puts "  found pin: $src, connecting $p -> $src via $netname"
            connect_bd_intf_net -intf_net $netname $src $p
            break
          } else {
            puts "  found no matching pin for $p"
          }
        }
      }
    }
  }

  # Checks all current runs at given step for errors, outputs their log files in case.
  # @param synthesis Checks synthesis runs if true, implementation runs otherwise.
  proc check_run_errors {{synthesis true}} {
    if {$synthesis} {
      set failed_runs [get_runs -filter "IS_SYNTHESIS == 1 && PROGRESS != {100%}"]
    } else {
      set failed_runs [get_runs -filter "IS_IMPLEMENTATION == 1 && PROGRESS != {100%}"]
    }
    # check number of failed runs
    if {[llength $failed_runs] > 0} {
      puts "at least one run failed, check these logs for errors:"
      foreach r $failed_runs {
        puts "  [get_property DIRECTORY $r]/runme.log"
      }
      exit 1
    }
  }

  # Platform API: Main entry point to generate the bitstream.
  proc generate {} {
    global bitstreamname
    # generate bitstream from given design and report utilization / timing closure
    set jobs [tapasco::get_number_of_processors]
    puts "  using $jobs parallel jobs"

    generate_target all [get_files system.bd]
    set synth_run [get_runs synth_1]
    set_property -dict [list \
      strategy Flow_PerfOptimized_high \
      STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AlternateRoutability \
      STEPS.SYNTH_DESIGN.ARGS.RETIMING true \
    ] $synth_run
    current_run $synth_run
    launch_runs -jobs $jobs $synth_run
    wait_on_run $synth_run
    if {[get_property PROGRESS $synth_run] != {100%}} { check_run_errors true }
    open_run $synth_run

    # call plugins
    tapasco::call_plugins "post-synth"

    set impl_run [get_runs impl_1]
    set_property -dict [list \
      STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore \
      STEPS.PHYS_OPT_DESIGN.IS_ENABLED true \
    ] $impl_run
    current_run $impl_run
    launch_runs -jobs $jobs -to_step route_design $impl_run
    wait_on_run $impl_run
    if {[get_property PROGRESS $impl_run] != {100%}} { check_run_errors false }
    open_run $impl_run

    # call plugins
    tapasco::call_plugins "post-impl"

    if {[get_property PROGRESS [get_runs $impl_run]] != "100%"} {
      error "ERROR: impl failed!"
    }
    report_timing_summary -warn_on_violation -file timing.txt
    report_utilization -file utilization.txt
    report_utilization -file utilization_userlogic.txt -cells [get_cells -hierarchical -filter {NAME =~ *target_ip_*}]
    report_power -file power.txt
    set wns [tapasco::get_wns_from_timing_report "timing.txt"]
    if {$wns >= -0.3} {
      write_bitstream -force "${bitstreamname}.bit"
    } else {
      error "timing failure, WNS: $wns"
    }
  }

  # Returns the base address of the PEs in the device address space.
  proc get_pe_base_address {} {
    error "Platform does not implement mandatory proc get_pe_base_address!"
  }

  proc get_address_map {{pe_base ""}} {
    error "Platform does not implement mandatory proc get_address_map!"
  }

  # Returns the number of interrupt controllers for the current design.
  proc number_of_interrupt_controllers {} {
    error "Platform does not implement mandatory proc number_of_interrupt_controllers!"
  }
}
