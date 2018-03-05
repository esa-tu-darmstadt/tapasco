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
	set ACLK_LITE [ create_bd_port -dir I -type clk ACLK_LITE ]
	set_property -dict [ list CONFIG.FREQ_HZ {100000000} CONFIG.PHASE {0.000} CONFIG.CLK_DOMAIN "${design_name}_ACLK_LITE" ] $ACLK_LITE
	set ARESETN_LITE [ create_bd_port -dir I -type rst ARESETN_LITE ]
	set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $ARESETN_LITE
	set_property CONFIG.ASSOCIATED_RESET ARESETN_LITE $ACLK_LITE


	set ACLK_M64 [ create_bd_port -dir I -type clk ACLK_M64 ]
	set_property -dict [ list CONFIG.FREQ_HZ {100000000} CONFIG.PHASE {0.000} CONFIG.CLK_DOMAIN "${design_name}_ACLK_M64" ] $ACLK_M64
	set ARESETN_M64 [ create_bd_port -dir I -type rst ARESETN_M64 ]
	set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $ARESETN_M64
	set_property CONFIG.ASSOCIATED_RESET ARESETN_M64 $ACLK_M64


	set ACLK_M32 [ create_bd_port -dir I -type clk ACLK_M32 ]
	set_property -dict [ list CONFIG.FREQ_HZ {100000000} CONFIG.PHASE {0.000} CONFIG.CLK_DOMAIN "${design_name}_ACLK_M32" ] $ACLK_M32
	set ARESETN_M32 [ create_bd_port -dir I -type rst ARESETN_M32 ]
	set_property -dict [ list CONFIG.POLARITY {ACTIVE_LOW}  ] $ARESETN_M32
	set_property CONFIG.ASSOCIATED_RESET ARESETN_M32 $ACLK_M32

	# Create instance: dual_dma_0, and set properties
	set dual_dma_0 [ create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:dual_dma:1.0 dual_dma_0]

	# Create External ports
	set IRQ [ create_bd_port -dir O IRQ ]
	connect_bd_net -net IRQ_net [get_bd_ports IRQ] [get_bd_pins dual_dma_0/IRQ]

	# Create axi interconnect
	set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0]
	set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1} CONFIG.STRATEGY {2} CONFIG.S00_HAS_DATA_FIFO {2} CONFIG.S01_HAS_DATA_FIFO {2}] [get_bd_cells axi_interconnect_0] $axi_interconnect_0
	# Create port connections
	connect_bd_net -net aclk_net_m64 [get_bd_ports ACLK_M64] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK]
	connect_bd_net -net aresetn_net_m64 [get_bd_ports ARESETN_M64] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/S01_ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN]

	# Create instance: master_0, and set properties
	set master_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cdn_axi_bfm master_0]
	set_property -dict [ list CONFIG.C_PROTOCOL_SELECTION {2} ] $master_0
	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins master_0/M_AXI_LITE] [get_bd_intf_pins dual_dma_0/S_AXI]
	# Create port connections
	connect_bd_net -net aclk_net_lite [get_bd_ports ACLK_LITE] [get_bd_pins master_0/M_AXI_LITE_ACLK] [get_bd_pins dual_dma_0/S_AXI_ACLK]
	connect_bd_net -net aresetn_net_lite [get_bd_ports ARESETN_LITE] [get_bd_pins master_0/M_AXI_LITE_ARESETN] [get_bd_pins dual_dma_0/S_AXI_ARESETN]

	# Create instance: master_1, and set properties
	set master_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cdn_axi_bfm master_1]
	set_property -dict [ list CONFIG.C_PROTOCOL_SELECTION {2} CONFIG.C_M_AXI4_LITE_ADDR_WIDTH {64} ] $master_1
	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins master_1/M_AXI_LITE] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
	# Create port connections
	connect_bd_net -net [get_bd_nets aclk_net_m64] [get_bd_ports ACLK_M64] [get_bd_pins master_1/m_axi_lite_aclk]
	connect_bd_net -net [get_bd_nets aresetn_net_m64] [get_bd_ports ARESETN_M64] [get_bd_pins master_1/m_axi_lite_aresetn]

	# Create instance: slave_0, and set properties
	set slave_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cdn_axi_bfm slave_0]
	set_property -dict [ list CONFIG.C_PROTOCOL_SELECTION {1} CONFIG.C_MODE_SELECT {1} CONFIG.C_S_AXI4_ADDR_WIDTH {64} CONFIG.C_S_AXI4_HIGHADDR {0x500000006000FFFF} CONFIG.C_S_AXI4_BASEADDR {0x5000000060000000} CONFIG.C_S_AXI4_MEMORY_MODEL_MODE {1} ] $slave_0
	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins slave_0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
	connect_bd_intf_net [get_bd_intf_pins dual_dma_0/M64_AXI] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
	# Create port connections
	connect_bd_net -net [get_bd_nets aclk_net_m64] [get_bd_ports ACLK_M64] [get_bd_pins slave_0/S_AXI_ACLK] [get_bd_pins dual_dma_0/M64_AXI_ACLK]
	connect_bd_net -net [get_bd_nets aresetn_net_m64] [get_bd_ports ARESETN_M64] [get_bd_pins slave_0/S_AXI_ARESETN] [get_bd_pins dual_dma_0/M64_AXI_ARESETN]

	# Create instance: slave_1, and set properties
	set slave_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cdn_axi_bfm slave_1]
	set_property -dict [ list CONFIG.C_PROTOCOL_SELECTION {1} CONFIG.C_MODE_SELECT {1} CONFIG.C_S_AXI4_HIGHADDR {0x4000FFFF} CONFIG.C_S_AXI4_BASEADDR {0x40000000} CONFIG.C_S_AXI4_MEMORY_MODEL_MODE {1} ] $slave_1
	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins slave_1/S_AXI] [get_bd_intf_pins dual_dma_0/M32_AXI]
	# Create port connections
	connect_bd_net -net aclk_net_m32 [get_bd_ports ACLK_M32] [get_bd_pins slave_1/S_AXI_ACLK] [get_bd_pins dual_dma_0/M32_AXI_ACLK]
	connect_bd_net -net aresetn_net [get_bd_ports ARESETN_M32] [get_bd_pins slave_1/S_AXI_ARESETN] [get_bd_pins dual_dma_0/M32_AXI_ARESETN]

	# Create instance: slave_2, and set properties
	#set slave_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cdn_axi_bfm slave_2]
	#set_property -dict [ list CONFIG.C_PROTOCOL_SELECTION {3} CONFIG.C_MODE_SELECT {1} CONFIG.C_S_AXIS_TDATA_WIDTH {32} CONFIG.C_S_AXIS_STROBE_NOT_USED {1} CONFIG.C_S_AXIS_KEEP_NOT_USED {1}  ] $slave_2


	# Create interface connections
	#connect_bd_intf_net -intf_net slave_2_s_axis [get_bd_intf_pins dual_dma_0/M_AXIS] [get_bd_intf_pins slave_2/S_AXIS]
	# Create port connections
	#connect_bd_net -net aclk_net [get_bd_ports ACLK] [get_bd_pins dual_dma_0/M_AXIS_ACLK] [get_bd_pins slave_2/S_AXIS_ACLK]
	#connect_bd_net -net aresetn_net [get_bd_ports ARESETN] [get_bd_pins dual_dma_0/M_AXIS_ARESETN] [get_bd_pins slave_2/S_AXIS_ARESETN]

	# Auto assign address
	assign_bd_address

	# Copy all address to interface_address.vh file
	set bd_path [file dirname [get_property NAME [get_files ${design_name}.bd]]]
	upvar 1 $offsetfile offset_file
	set offset_file "${bd_path}/dual_dma_v1_0_tb_include.vh"
	set fp [open $offset_file "w"]
	puts $fp "`ifndef dual_dma_v1_0_tb_include_vh_"
	puts $fp "`define dual_dma_v1_0_tb_include_vh_\n"
	puts $fp "//Configuration current bd names"
	puts $fp "`define BD_INST_NAME ${design_name}_i"
	puts $fp "`define BD_WRAPPER ${design_name}_wrapper\n"
	puts $fp "//Configuration address parameters"

	set offset [get_property OFFSET [get_bd_addr_segs -of_objects [get_bd_addr_spaces master_0/Data_lite]]]
	set offset_hex [string replace $offset 0 1 "32'h"]
	puts $fp "`define S_AXI_SLAVE_ADDRESS ${offset_hex}"

	puts $fp "`endif"
	close $fp
}

set ip_path [file dirname [file normalize [get_property XML_FILE_NAME [ipx::get_cores esa.informatik.tu-darmstadt.de:user:dual_dma:1.0]]]]
set test_bench_file ${ip_path}/example_designs/bfm_design/dual_dma_v1_0_tb.v
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
	set design_name "dual_dma_v1_0_bfm_${i}"
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
remove_files -quiet -fileset sim_1 dual_dma_v1_0_tb_include.vh
import_files -fileset sim_1 -norecurse -force $interface_address_vh_file
set_property top dual_dma_v1_0_tb [get_filesets sim_1]
set_property top_lib {} [get_filesets sim_1]
set_property top_file {} [get_filesets sim_1]
launch_xsim -simset sim_1 -mode behavioral
restart
run 1000 us
