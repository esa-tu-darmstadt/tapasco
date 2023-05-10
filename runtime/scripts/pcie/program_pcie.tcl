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

## Download a bit file to the FPGA on the supported PCIe devices

#set default values
set wait 1000
set dev {xc7vx690t_0|xcvu9p_0|xcvu095_0|xcu250_0|xcvu37p_0|xcu280_0|xcu280_u55c_0|xcu50_u55n_0|xcvc1902_1}
set probes_file {}
set program_file {}
set target {}
set list_adapter false

if { $argc > 0 } {
  for {set i 0} {$i < [llength $::argv]} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--bit"          { incr i; set program_file [lindex $::argv $i]; puts "using $program_file as bitstream" }
      "--ltx"          { incr i; set probes_file [lindex $::argv $i]; puts "using $probe_file for probes" }
      "--adapter"      { incr i; set target [lindex $::argv $i] }
      "--list-adapter" { incr i; set list_adapter [expr [lindex $::argv $i] == 1] }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
} else {
  puts "no arguments given, aborting"
  exit 1
}

proc init {} {
  open_hw
  connect_hw_server
}

proc deinit {{retcode 0}} {
  disconnect_hw_server
  close_hw
  exit $retcode
}

proc list_adapters {} {
  variable dev
  puts "Found the following programming adapters:"
  foreach t [get_hw_targets] {
    open_hw_target -quiet $t
    set devs [get_hw_devices -quiet -regexp "NAME ~= \{$dev\}*"]
    if {[llength $devs] > 0} {
      puts "Adapter $t: $devs"
    } {
      puts "Adapter $t: No devices supported by TaPaSCo"
    }
    close_hw_target -quiet $t
  }
  puts "Please use --adapter <ADAPTER> to select the correct device."
}

# open server
init

if {$list_adapter} {
  list_adapters
  # do not indicate error
  deinit
}

if {[llength [get_hw_targets -quiet]] == 0} {
  puts "Did not find any programming adapters."
  deinit 1
}

if {[llength [get_hw_targets -quiet *$target]] != 1 && $target != "NOADAPTER"} {
  puts "Did not find the requested adapter $target. The following adapters are available: "
  list_adapters
  deinit 1
}

if {[llength [get_hw_targets]] > 0 && $target == "NOADAPTER"} {
  puts "Found multiple programming adapters. Please specify one from the following list:"
  list_adapters
  deinit 1
}

if {$target == "NOADAPTER"} {
  set target "*"
}

current_hw_target [get_hw_targets *$target]
open_hw_target [current_hw_target]
set founddev [current_hw_device $dev]
if {[llength $founddev] > 0} {
  puts "programming $target:$founddev ..."

  # set bitstream file
  set_property PROGRAM.FILE $program_file [current_hw_device]
  # set probes file (if any)
  set_property PROBES.FILE $probes_file [current_hw_device]

  ## program device
  program_hw_devices [current_hw_device]

  if { $probes_file != {} } {
    puts "waiting for ILA core to appear ..."
    after $wait
    refresh_hw_device [current_hw_device]
  }

  ## close everything
  close_hw_target
  deinit
} else {
  puts "could not find any supported device, aborting."
  deinit 1
}
