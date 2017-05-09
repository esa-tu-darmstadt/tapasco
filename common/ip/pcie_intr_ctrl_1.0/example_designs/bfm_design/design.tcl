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
proc create_ipi_design { offsetfile design_name } {
	create_bd_design $design_name
	open_bd_design $design_name

	# Create Clock and Reset Ports
	set axi_aclk [ create_bd_port -dir I -type clk axi_aclk ]
	set_property -dict [ list CONFIG.FREQ_HZ {100000000} CONFIG.PHASE {0.000} CONFIG.CLK_DOMAIN "${design_name}_axi_aclk" ] $axi_aclk

	set axi_aresetn [ create_bd_port -dir I -type rst axi_aresetn ]
	set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $axi_aresetn
	set_property CONFIG.ASSOCIATED_RESET ARESETN $axi_aclk

	set msi_enable [ create_bd_port -dir I msi_enable ]
	set msi_grant [ create_bd_port -dir I msi_grant ]
	set msi_vector_width [ create_bd_port -dir I -from 2 -to 0 msi_vector_width ]

	set irq_in_0 [ create_bd_port -dir I irq_in_0 ]
	set irq_in_1 [ create_bd_port -dir I irq_in_1 ]
	set irq_in_2 [ create_bd_port -dir I irq_in_2 ]
	set irq_in_3 [ create_bd_port -dir I irq_in_3 ]
	set irq_in_4 [ create_bd_port -dir I irq_in_4 ]
	set irq_in_5 [ create_bd_port -dir I irq_in_5 ]
	set irq_in_6 [ create_bd_port -dir I irq_in_6 ]
	set irq_in_7 [ create_bd_port -dir I irq_in_7 ]

	set msi_vector_num [ create_bd_port -dir O -from 4 -to 0 msi_vector_num ]
	set irq_out [ create_bd_port -dir O irq_out ]

	# Create instance: pcie_intr_ctrl_0, and set properties
	set pcie_intr_ctrl_0 [ create_bd_cell -type ip -vlnv ESA:user:pcie_intr_ctrl:1.0 pcie_intr_ctrl_0]

	# Create port connections
	connect_bd_net -net aclk_net [get_bd_ports axi_aclk] [get_bd_pins pcie_intr_ctrl_0/axi_aclk]
	connect_bd_net -net axi_aresetn [get_bd_ports axi_aresetn] [get_bd_pins pcie_intr_ctrl_0/axi_aresetn]

	connect_bd_net -net msi_enable_net [get_bd_ports msi_enable] [get_bd_pins pcie_intr_ctrl_0/msi_enable]
	connect_bd_net -net msi_grant_net [get_bd_ports msi_grant] [get_bd_pins pcie_intr_ctrl_0/msi_grant]
	connect_bd_net -net msi_vector_width_net [get_bd_ports msi_vector_width] [get_bd_pins pcie_intr_ctrl_0/msi_vector_width]

	connect_bd_net -net irq_in_0_net [get_bd_ports irq_in_0] [get_bd_pins pcie_intr_ctrl_0/irq_in_0]
	connect_bd_net -net irq_in_1_net [get_bd_ports irq_in_1] [get_bd_pins pcie_intr_ctrl_0/irq_in_1]
	connect_bd_net -net irq_in_2_net [get_bd_ports irq_in_2] [get_bd_pins pcie_intr_ctrl_0/irq_in_2]
	connect_bd_net -net irq_in_3_net [get_bd_ports irq_in_3] [get_bd_pins pcie_intr_ctrl_0/irq_in_3]
	connect_bd_net -net irq_in_4_net [get_bd_ports irq_in_4] [get_bd_pins pcie_intr_ctrl_0/irq_in_4]
	connect_bd_net -net irq_in_5_net [get_bd_ports irq_in_5] [get_bd_pins pcie_intr_ctrl_0/irq_in_5]
	connect_bd_net -net irq_in_6_net [get_bd_ports irq_in_6] [get_bd_pins pcie_intr_ctrl_0/irq_in_6]
	connect_bd_net -net irq_in_7_net [get_bd_ports irq_in_7] [get_bd_pins pcie_intr_ctrl_0/irq_in_7]

	connect_bd_net -net msi_vector_num_net [get_bd_ports msi_vector_num] [get_bd_pins pcie_intr_ctrl_0/msi_vector_num]
	connect_bd_net -net irq_out_net [get_bd_ports irq_out] [get_bd_pins pcie_intr_ctrl_0/irq_out]
	
	#set S_AXI_INTR_IRQ [ create_bd_port -dir O -type intr irq ]
	#connect_bd_net [get_bd_pins /pcie_intr_ctrl_0/irq] ${S_AXI_INTR_IRQ}

	# Copy all address to interface_address.vh file
	set bd_path [file dirname [get_property NAME [get_files ${design_name}.bd]]]
	upvar 1 $offsetfile offset_file
	set offset_file "${bd_path}/pcie_intr_ctrl_v1_0_tb_include.vh"
	set fp [open $offset_file "w"]
	puts $fp "`ifndef pcie_intr_ctrl_v1_0_tb_include_vh_"
	puts $fp "`define pcie_intr_ctrl_v1_0_tb_include_vh_\n"
	puts $fp "//Configuration current bd names"
	puts $fp "`define BD_INST_NAME ${design_name}_i"
	puts $fp "`define BD_WRAPPER ${design_name}_wrapper\n"
	puts $fp "//Configuration address parameters"

	set offset "12340000"
	set offset_hex [string replace $offset 0 1 "32'h"]
	puts $fp "`define S_AXI_INTR_SLAVE_ADDRESS ${offset_hex}"

	puts $fp "\n//Interrupt configuration parameters"

	set param_irq_active_state [get_property CONFIG.C_IRQ_ACTIVE_STATE [get_bd_cells pcie_intr_ctrl_0]]
	set param_irq_sensitivity [get_property CONFIG.C_IRQ_SENSITIVITY [get_bd_cells pcie_intr_ctrl_0]]
	set param_intr_active_state [get_property CONFIG.C_INTR_ACTIVE_STATE [get_bd_cells pcie_intr_ctrl_0]]
	set param_intr_sensitivity [get_property CONFIG.C_INTR_SENSITIVITY [get_bd_cells pcie_intr_ctrl_0]]

	puts $fp "`define IRQ_ACTIVE_STATE ${param_irq_active_state}"
	puts $fp "`define IRQ_SENSITIVITY ${param_irq_sensitivity}"
	puts $fp "`define INTR_ACTIVE_STATE ${param_intr_active_state}"
	puts $fp "`define INTR_SENSITIVITY ${param_intr_sensitivity}\n"
	puts $fp "`endif"
	close $fp
}

set ip_path [file dirname [file normalize [get_property XML_FILE_NAME [ipx::get_cores ESA:user:pcie_intr_ctrl:1.0]]]]
set test_bench_file ${ip_path}/example_designs/bfm_design/pcie_intr_ctrl_v1_0_tb.v
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
	set design_name "pcie_intr_ctrl_v1_0_bfm_${i}"
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
remove_files -quiet -fileset sim_1 pcie_intr_ctrl_v1_0_tb_include.vh
import_files -fileset sim_1 -norecurse -force $interface_address_vh_file
set_property top pcie_intr_ctrl_v1_0_tb [get_filesets sim_1]
set_property top_lib {} [get_filesets sim_1]
set_property top_file {} [get_filesets sim_1]
launch_xsim -simset sim_1 -mode behavioral
restart
run 1000 us
