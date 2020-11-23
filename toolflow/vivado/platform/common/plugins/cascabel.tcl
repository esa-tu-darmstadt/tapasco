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

if {[tapasco::is_feature_enabled "Cascabel"]} {
	proc create_cascabel_ip_core {} {
		set composition [tapasco::get_composition]
		set pe_count 0
		set kid_count 0
		set pe_arr ""
		set kid_arr ""
		dict for {k v} $composition {
			set id [dict get $composition $k id]
			set no [dict get $composition $k count]
			set pe_count [expr "$pe_count + $no"]
			for {set i 0} {$i < $no} {incr i} {
				set pe_arr "$pe_arr,$id"
			}
			incr kid_count
			set kid_arr "$kid_arr,$id"
		}
		set pe_arr [string trimleft $pe_arr ,]
		set kid_arr [string trimleft $kid_arr ,]
		set config_fd [open "$::env(TAPASCO_HOME_TCL)/common/ip/Cascabel/src/CascabelConfiguration.bsv" "w"]
		puts $config_fd "package CascabelConfiguration;"
		puts $config_fd "import CascabelTypes::*;"
		puts $config_fd "typedef $pe_count PE_COUNT;"
		puts $config_fd "typedef $kid_count KID_COUNT;"
		puts $config_fd "KID_TYPE pe_arr[$pe_count] = {$pe_arr};"
		puts $config_fd "KID_TYPE kid_arr[$kid_count] = {$kid_arr};"
		puts $config_fd "endpackage"
		close $config_fd
		exec -ignorestderr $::env(TAPASCO_HOME_TCL)/common/ip/Cascabel/build_ip.sh
		update_ip_catalog -rebuild
	}

	proc create_custom_subsystem_cascabel {} {
		# currently runs in design_clk clock domain
		puts "  instantiating cascabel core ..."
		create_cascabel_ip_core
		set cascabel [create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:Cascabel Cascabel]
		puts "  creating slave port S_CASCABEL ..."
		set s_port [create_bd_intf_pin -vlnv [tapasco::ip::get_vlnv "aximm_intf"] -mode Slave "S_CASCABEL"]
		puts "  creating slave port M_ARCH_CASCABEL ..."
		set m_port [create_bd_intf_pin -vlnv [tapasco::ip::get_vlnv "aximm_intf"] -mode Master "M_ARCH_CASCABEL"]
		puts "  creating interrupt ports ..."
		# TODO: mechanism for handling more than 32 interrupts
		set out_intr_pin [get_bd_pins $cascabel/intr_host]
		set out_intr [create_bd_pin -dir O -type intr -from [get_property LEFT $out_intr_pin] -to [get_property RIGHT $out_intr_pin] "intr_0"]
		connect_bd_net [get_bd_pins $out_intr] $out_intr_pin
		set in_intr_pin [get_bd_pins $cascabel/intr_intr]
		set in_intr [create_bd_pin -dir I -from [get_property LEFT $in_intr_pin] -to [get_property RIGHT $in_intr_pin] "intr_cascabel_0"]
		connect_bd_net [get_bd_pins $in_intr] $in_intr_pin
		puts "  wiring ..."
		set ic [tapasco::ip::create_axi_ic "cascabel_ic" 1 2]
		# force to 512 bit xbar width so that the Smartconnect on pcie does not throw an error
		set_property -dict [list CONFIG.ENABLE_ADVANCED_OPTIONS {1}] $ic
		set_property -dict [list CONFIG.XBAR_DATA_WIDTH {512}] $ic
		connect_bd_intf_net $s_port [get_bd_intf_pins $ic/S00_AXI]
		connect_bd_intf_net [get_bd_intf_pins $cascabel/S_AXI_CONTROL] [get_bd_intf_pins $ic/M00_AXI]
		connect_bd_intf_net [get_bd_intf_pins $cascabel/S_AXI_PACKET] [get_bd_intf_pins $ic/M01_AXI]
		connect_bd_intf_net $m_port [get_bd_intf_pins $cascabel/M_AXI]

		# clocking and reset
		connect_bd_net [tapasco::subsystem::get_port "host" "clk"] [get_bd_pins $cascabel/CLK]
		connect_bd_net [tapasco::subsystem::get_port "host" "clk"] [get_bd_pins $ic/M00_ACLK] [get_bd_pins $ic/M01_ACLK]
		connect_bd_net [tapasco::subsystem::get_port "design" "clk"] [get_bd_pins $cascabel/*design_clk]
		connect_bd_net [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"] [get_bd_pins $cascabel/*design_rst*]
		connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] [get_bd_pins $cascabel/RST_N]
		connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] [get_bd_pins $ic/M00_ARESETN] [get_bd_pins $ic/M01_ARESETN]
		connect_bd_net [tapasco::subsystem::get_port "host" "clk"] [get_bd_pins $ic/ACLK] [get_bd_pins $ic/S00_ACLK]
		connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] [get_bd_pins $ic/ARESETN] [get_bd_pins $ic/S00_ARESETN]
		puts "  done!"
	}
}

