#
# Copyright (C) 2017 Jens Korinth, TU Darmstadt
# Copyright (C) 2018 Jaco A. Hofmann, TU Darmstadt
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
## Download a bit file to the FPGA on the supported PCIe devices

#set default values
set wait 1000
set dev {xc7vx690t_0|xcvu9p_0|xcvu095_0|xcu250_0|xcvu37p_0|xcu280_0}
set probes_file {}
set program_file {}
set devid -1
set target {}

if { $argc > 0 } {
  set program_file [lindex $argv 0]
	puts "using $program_file as bitstream"
  if { $argc > 1 } {
    set probes_file [lindex $argv 1]
	  puts "using $probe_file for probes"
  }
} else {
  puts "no bitstream file given, aborting"
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

# open server
init

foreach t [get_hw_targets] {
  puts "opening target $t ..."
  open_hw_target $t
  set devid [lsearch -regexp [get_hw_devices] $dev]
  close_hw_target $t
  if {$devid >= 0} {
    set target $t
    puts "found device @ $target:$devid"
    break;
  }
}

# check if device was found
if { $devid >= 0 } {
  puts "programming $target:$devid ..."
  current_hw_target $target
  open_hw_target [current_hw_target]
  current_hw_device $dev

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
