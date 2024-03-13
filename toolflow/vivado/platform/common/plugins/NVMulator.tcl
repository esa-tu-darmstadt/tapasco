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
                puts "ERROR: NVMulator is not supported by specified platform"
                exit 1
            }
            
            set oldCurInst [current_bd_instance .]
            
            current_bd_instance "/memory"
            set memory_p_aresetn [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
            set memory_clk [tapasco::subsystem::get_port "mem" "clk"]
            set design_clk [tapasco::subsystem::get_port "design" "clk"]
            
            set nvmulator [create_bd_cell -type ip -vlnv esa.informatik.tu-darmstadt.de:user:NVEmulator:1.0 NVMulator]
            connect_bd_net [get_bd_pins $memory_clk] [get_bd_pins $nvmulator/CLK]
            connect_bd_net [get_bd_pins $memory_p_aresetn] [get_bd_pins $nvmulator/RST_N]
            
            delete_bd_objs [get_bd_intf_nets /memory/mig_ic_M00_AXI]
            connect_bd_intf_net [get_bd_intf_pins $nvmulator/M_AXI_MIG] [get_bd_intf_pins /memory/mig/C0_DDR4_S_AXI]
            connect_bd_intf_net [get_bd_intf_pins /memory/mig_ic/M00_AXI] [get_bd_intf_pins $nvmulator/S_AXI_NV]
            
            set nvmulator_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 nvmulator_ic]
            set_property -dict [list CONFIG.NUM_CLKS {2} CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells $nvmulator_ic]
            connect_bd_net [get_bd_pins $nvmulator_ic/aclk] [get_bd_pins $memory_clk]
            connect_bd_net [get_bd_pins $nvmulator_ic/aclk1] [get_bd_pins $design_clk] 
            connect_bd_net [get_bd_pins  $memory_p_aresetn] [get_bd_pins $nvmulator_ic/aresetn]
            
            set s_nvm [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_NVM"]
            connect_bd_intf_net [get_bd_intf_pins /memory/S_NVM] [get_bd_intf_pins $nvmulator_ic/S00_AXI]
            connect_bd_intf_net [get_bd_intf_pins $nvmulator_ic/M00_AXI] [get_bd_intf_pins $nvmulator/S_AXI]
            
            current_bd_instance "/host"
            set m_nvm [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_NVM"]
            set num_host_out_old [get_property CONFIG.NUM_MI [get_bd_cells /host/out_ic]]
            set num_host_out [expr "$num_host_out_old + 1"]
            set_property -dict [list CONFIG.NUM_MI $num_host_out] [get_bd_cells /host/out_ic]
            connect_bd_intf_net [get_bd_intf_pins /host/out_ic/[format "M%02d_AXI" $num_host_out_old]] $m_nvm
            
            connect_bd_intf_net [get_bd_intf_pins /host/M_NVM] [get_bd_intf_pins /memory/S_NVM]
            
            current_bd_instance $oldCurInst
        }
        return {}
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
