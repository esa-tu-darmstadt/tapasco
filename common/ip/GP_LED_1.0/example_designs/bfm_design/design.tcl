#
# Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
proc create_ipi_design { offsetfile design_name } {
	create_bd_design $design_name
	open_bd_design $design_name

	# Create Clock and Reset Ports
	set ACLK [ create_bd_port -dir I -type clk ACLK ]
	set_property -dict [ list CONFIG.FREQ_HZ {100000000} CONFIG.PHASE {0.000} CONFIG.CLK_DOMAIN "${design_name}_ACLK" ] $ACLK
	set ARESETN [ create_bd_port -dir I -type rst ARESETN ]
	set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $ARESETN
	set_property CONFIG.ASSOCIATED_RESET ARESETN $ACLK

	set IN_0 [ create_bd_port -dir I IN_0 ]
	set IN_1 [ create_bd_port -dir I IN_1 ]
	set IN_2 [ create_bd_port -dir I IN_2 ]
	set IN_3 [ create_bd_port -dir I IN_3 ]
	set IN_4 [ create_bd_port -dir I IN_4 ]
	set IN_5 [ create_bd_port -dir I IN_5 ]

	set LED_Port [ create_bd_port -dir O -from 7 -to 0 LED_Port ]

	# Create instance: GP_LED_0, and set properties
	set GP_LED_0 [ create_bd_cell -type ip -vlnv ESA:user:GP_LED:1.0 GP_LED_0]

	# Create port connections
	connect_bd_net -net aclk_net [get_bd_ports ACLK] [get_bd_pins GP_LED_0/aclk]
	connect_bd_net -net aresetn_net [get_bd_ports ARESETN] [get_bd_pins GP_LED_0/aresetn]

	connect_bd_net -net in_0_net [get_bd_ports IN_0] [get_bd_pins GP_LED_0/IN_0]
	connect_bd_net -net in_1_net [get_bd_ports IN_1] [get_bd_pins GP_LED_0/IN_1]
	connect_bd_net -net in_2_net [get_bd_ports IN_2] [get_bd_pins GP_LED_0/IN_2]
	connect_bd_net -net in_3_net [get_bd_ports IN_3] [get_bd_pins GP_LED_0/IN_3]
	connect_bd_net -net in_4_net [get_bd_ports IN_4] [get_bd_pins GP_LED_0/IN_4]
	connect_bd_net -net in_5_net [get_bd_ports IN_5] [get_bd_pins GP_LED_0/IN_5]

	connect_bd_net -net led_port_net [get_bd_ports LED_Port] [get_bd_pins GP_LED_0/LED_Port]

	# Copy all address to interface_address.vh file
	set bd_path [file dirname [get_property NAME [get_files ${design_name}.bd]]]
	upvar 1 $offsetfile offset_file
	set offset_file "${bd_path}/GP_LED_v1_0_tb_include.vh"
	set fp [open $offset_file "w"]
	puts $fp "`ifndef GP_LED_v1_0_tb_include_vh_"
	puts $fp "`define GP_LED_v1_0_tb_include_vh_\n"
	puts $fp "//Configuration current bd names"
	puts $fp "`define BD_INST_NAME ${design_name}_i"
	puts $fp "`define BD_WRAPPER ${design_name}_wrapper\n"
	puts $fp "//Configuration address parameters"

	#set offset [get_property OFFSET [get_bd_addr_segs -of_objects [get_bd_addr_spaces master_0/Data_lite]]]
	set offset "12340000"
	set offset_hex [string replace $offset 0 1 "32'h"]
	puts $fp "`define S00_AXI_SLAVE_ADDRESS ${offset_hex}"

	puts $fp "`endif"
	close $fp
}

set ip_path [file dirname [file normalize [get_property XML_FILE_NAME [ipx::get_cores ESA:user:GP_LED:1.0]]]]
set test_bench_file ${ip_path}/example_designs/bfm_design/GP_LED_v1_0_tb.v
set interface_address_vh_file ""

# Set IP Repository and Update IP Catalogue 
set repo_paths [get_property ip_repo_paths [current_fileset]] 
if { [lsearch -exact -nocase $repo_paths $ip_path ] == -1 } {
	set_property ip_repo_paths "$ip_path [get_property ip_repo_paths [current_fileset]]" [current_fileset]
	update_ip_catalog
}

set design_name ""
set all_bd {}
set all_bd_files [get_files *.bd -quiet]
foreach file $all_bd_files {
set file_name [string range $file [expr {[string last "/" $file] + 1}] end]
set bd_name [string range $file_name 0 [expr {[string last "." $file_name] -1}]]
lappend all_bd $bd_name
}

for { set i 1 } { 1 } { incr i } {
	set design_name "GP_LED_v1_0_bfm_${i}"
	if { [lsearch -exact -nocase $all_bd $design_name ] == -1 } {
		break
	}
}

create_ipi_design interface_address_vh_file ${design_name}
validate_bd_design

set wrapper_file [make_wrapper -files [get_files ${design_name}.bd] -top -force]
import_files -force -norecurse $wrapper_file

set_property SOURCE_SET sources_1 [get_filesets sim_1]
import_files -fileset sim_1 -norecurse -force $test_bench_file
remove_files -quiet -fileset sim_1 GP_LED_v1_0_tb_include.vh
import_files -fileset sim_1 -norecurse -force $interface_address_vh_file
set_property top GP_LED_v1_0_tb [get_filesets sim_1]
set_property top_lib {} [get_filesets sim_1]
set_property top_file {} [get_filesets sim_1]
launch_xsim -simset sim_1 -mode behavioral
restart
run 1000 us
