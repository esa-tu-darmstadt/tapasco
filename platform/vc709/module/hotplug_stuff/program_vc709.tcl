#
# Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
#
# This file is part of ThreadPoolComposer (TPC).
#
# ThreadPoolComposer is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ThreadPoolComposer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
#
## Download a bit file to the FPGA on the VC709

#set default values
set dev_sel 0
set wait_intv 1000
set probes_file {}
set program_file {design_1_wrapper.bit}

# override default values from tclargs
if { $argc == 1 } {
	set program_file [lindex $argv 0]
	puts "Using $program_file as bitstream"

} else { if { $argc == 2 } {
	set program_file [lindex $argv 0]
	set probes_file [lindex $argv 1]
	puts "Using $program_file as bitstream"
	puts "Using $probe_file for probes"
} else {
	puts "Using default values for bitstream and no probes"
} }

## Opening hardware and refresh to actual status (ignoring probes)
open_hw
connect_hw_server

current_hw_target [lindex [get_hw_targets -of_objects [get_hw_servers localhost]] $dev_sel]
set_property PARAM.FREQUENCY 30000000 [current_hw_target]
open_hw_target [current_hw_target]

current_hw_device [lindex [get_hw_devices] $dev_sel]
refresh_hw_device -update_hw_probes false [current_hw_device]

## Set download a bit file
set_property PROBES.FILE $probes_file [current_hw_device]
set_property PROGRAM.FILE $program_file [current_hw_device]

## Program device and refresh after short delay to allow ILA-Core to be seen
program_hw_devices [current_hw_device]

after $wait_intv
refresh_hw_device [current_hw_device]

## Close everything
close_hw_target
disconnect_hw_server
close_hw

exit

