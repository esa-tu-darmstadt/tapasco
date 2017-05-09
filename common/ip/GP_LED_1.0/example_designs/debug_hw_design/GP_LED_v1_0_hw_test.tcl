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
# Runtime Tcl commands to interact with - GP_LED_v1_0

# Sourcing design address info tcl
set bd_path [get_property DIRECTORY [current_project]]/[current_project].srcs/[current_fileset]/bd
source ${bd_path}/GP_LED_v1_0_include.tcl

# jtag axi master interface hardware name, change as per your design.
set jtag_axi_master hw_axi_1
set ec 0

# hw test script
# Delete all previous axis transactions
if { [llength [get_hw_axi_txns -quiet]] } {
	delete_hw_axi_txn [get_hw_axi_txns -quiet]
}


# Test all lite slaves.
set wdata_1 abcd1234

# Test: S00_AXI
# Create a write transaction at s00_axi_addr address
create_hw_axi_txn w_s00_axi_addr [get_hw_axis $jtag_axi_master] -type write -address $s00_axi_addr -data $wdata_1
# Create a read transaction at s00_axi_addr address
create_hw_axi_txn r_s00_axi_addr [get_hw_axis $jtag_axi_master] -type read -address $s00_axi_addr
# Initiate transactions
run_hw_axi r_s00_axi_addr
run_hw_axi w_s00_axi_addr
run_hw_axi r_s00_axi_addr
set rdata_tmp [get_property DATA [get_hw_axi_txn r_s00_axi_addr]]
# Compare read data
if { $rdata_tmp == $wdata_1 } {
	puts "Data comparison test pass for - S00_AXI"
} else {
	puts "Data comparison test fail for - S00_AXI, expected-$wdata_1 actual-$rdata_tmp"
	inc ec
}

# Check error flag
if { $ec == 0 } {
	 puts "PTGEN_TEST: PASSED!" 
} else {
	 puts "PTGEN_TEST: FAILED!" 
}

