# Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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

namespace eval nvmulator {

	proc is_nvmulator_supported {} {
		return false
	}

	proc add_nvmulator {} {
		if {[tapasco::is_feature_enabled "NVMulator"]} {
		if {![is_nvmulator_supported]} {
			puts "ERROR: NV-Emulator is not supported by specified platform"
			exit 1
		}
		
		save_bd_design
		puts "Adding NVMulator 0 : memory-side"
		create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:NVEmulator:1.0 /memory/NVEmulator_0
		connect_bd_net [get_bd_pins /memory/mig/c0_ddr4_ui_clk] [get_bd_pins /memory/NVEmulator_0/CLK]
		connect_bd_net [get_bd_pins /memory/mem_peripheral_aresetn] [get_bd_pins /memory/NVEmulator_0/RST_N]


		puts "Adding NVMulator 0 programmer: memory-side"		
		delete_bd_objs [get_bd_intf_nets /memory/mig_ic_M00_AXI]
		connect_bd_intf_net [get_bd_intf_pins /memory/NVEmulator_0/M_AXI_MIG] [get_bd_intf_pins /memory/mig/C0_DDR4_S_AXI]
		connect_bd_intf_net [get_bd_intf_pins /memory/mig_ic/M00_AXI] [get_bd_intf_pins /memory/NVEmulator_0/S_AXI_NV]

		puts "Connecting NVMulator programmer: memory-side"
		create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 /memory/smartconnect_0
		set_property -dict [list CONFIG.NUM_CLKS {2} CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells /memory/smartconnect_0]
		connect_bd_net [get_bd_pins /memory/smartconnect_0/aclk] [get_bd_pins /memory/mig/c0_ddr4_ui_clk]
		connect_bd_net [get_bd_pins /memory/smartconnect_0/aclk1] [get_bd_pins /memory/design_clk] 
		connect_bd_net [get_bd_pins  /memory/mem_peripheral_aresetn] [get_bd_pins /memory/smartconnect_0/aresetn]
		current_bd_instance "/memory"
		set s_nvm [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_NVM"]
		connect_bd_intf_net [get_bd_intf_pins /memory/S_NVM] [get_bd_intf_pins /memory/smartconnect_0/S00_AXI]
		connect_bd_intf_net [get_bd_intf_pins /memory/smartconnect_0/M00_AXI] [get_bd_intf_pins /memory/NVEmulator_0/S_AXI]

		puts "Connecting NVMulator programmer: host-side"
		current_bd_instance "/host"
		set m_nvm [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_NVM"]
		set num_host_out_old [get_property CONFIG.NUM_MI [get_bd_cells /host/out_ic]]
		set num_host_out [expr "$num_host_out_old + 1"]
		set_property -dict [list CONFIG.NUM_MI $num_host_out] [get_bd_cells /host/out_ic]
		connect_bd_intf_net [get_bd_intf_pins /host/out_ic/[format "M%02d_AXI" $num_host_out_old]] $m_nvm
		
		puts "Connecting NVMulator programmer: host to memory"
		connect_bd_intf_net [get_bd_intf_pins /host/M_NVM] [get_bd_intf_pins /memory/S_NVM]
		
		current_bd_instance
	}
}

	proc addressmap {{args {}}} {
		if {[tapasco::is_feature_enabled "NVMulator"]} {
			set args [lappend args "M_NVM" [list 0x50000 0x10000 0 "PLATFORM_COMPONENT_NVMULATOR"]]
		}
		return $args
	}
}

tapasco::register_plugin "platform::nvmulator::add_nvmulator" "pre-wiring"
tapasco::register_plugin "platform::nvmulator::addressmap" "post-address-map"
