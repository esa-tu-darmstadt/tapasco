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

if {[tapasco::is_feature_enabled "Debug"]} {
  # add an AXI debug hub to a versal system, which is required for ILA cores
  proc create_custom_subsystem_debug {{args {}}} {
    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set host_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set axi_dbg [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DBG"]

    # create and connect debug hub IP
    set axi_dbg_hub [tapasco::ip::create_axi_dbg_hub dbg_hub_0]
    connect_bd_net $host_aclk [get_bd_pins $axi_dbg_hub/aclk]
    connect_bd_net $host_p_aresetn [get_bd_pins $axi_dbg_hub/aresetn]
    connect_bd_intf_net $axi_dbg [get_bd_intf_pins $axi_dbg_hub/S_AXI]

    return $args
  }

  namespace eval debug {
    proc connect_debug_hub {{args {}}} {
      set old_bd_inst [current_bd_instance]
      current_bd_instance "/memory"

      set axi_dbg [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DBG"]
      set noc [get_bd_cells *noc*]

      # add additional AXI master to NoC and connect it to PS PMC master
      set axi_master_num [get_property CONFIG.NUM_MI $noc]
      set axi_master_name [format "M%02s_AXI" $axi_master_num]
      set pmc_connections [get_property CONFIG.CONNECTIONS [get_bd_intf_pins $noc/S05_AXI]]
      set_property CONFIG.NUM_MI [expr $axi_master_num+1] $noc
      set_property CONFIG.CATEGORY {pl} [get_bd_intf_pins $noc/$axi_master_name]
      lappend pmc_connections $axi_master_name {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}
      set_property CONFIG.CONNECTIONS $pmc_connections [get_bd_intf_pins $noc/S05_AXI]

      connect_bd_intf_net [get_bd_intf_pins $noc/$axi_master_name] $axi_dbg

      current_bd_instance $old_bd_inst
      return $args
    }

    proc dbg_addressmap {{args {}}} {
      set args [lappend args "M_DBG" [list 0x20200000000 0 0 ""]]
      return $args
    }
  }

  tapasco::register_plugin "platform::debug::connect_debug_hub" "pre-wiring"
  tapasco::register_plugin "platform::debug::dbg_addressmap" "post-address-map"
}
