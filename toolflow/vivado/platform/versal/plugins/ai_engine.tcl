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

if {[tapasco::is_feature_enabled "AI-Engine"]} {
  # add the unconfigured AI engine cell to the block design
  proc create_custom_subsystem_aie {{args {}}} {
    set aie_clk [create_bd_pin -type "clk" -dir "O" "aie_clk"]
    set axi_aie [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AIE"]

    # name for ai engine needs to be exactly like this for xsa export
    set aie [create_bd_cell -type ip -vlnv xilinx.com:ip:ai_engine:2.0 ai_engine_0]

    set aie_core_freq [tapasco::get_feature_option "AI-Engine" "freq" -1]
    if {$aie_core_freq != -1} {
      puts "Setting AI Engine core frequency to $aie_core_freq"
      set_property CONFIG.AIE_CORE_REF_CTRL_FREQMHZ $aie_core_freq $aie
    }

    connect_bd_net [get_bd_pins $aie/s00_axi_aclk] $aie_clk
    connect_bd_intf_net $axi_aie [get_bd_intf_pins $aie/S00_AXI]

    return $args
  }

  namespace eval versal {
    proc connect_aie_engines {{args {}}} {
      set old_bd_inst [current_bd_instance .]
      current_bd_instance "/memory"

      set aie_clk [create_bd_pin -type "clk" -dir "I" "aie_clk"]
      set axi_aie [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_AIE"]
      set cips [get_bd_cells *cips*]
      set noc [get_bd_cells *noc*]

      # create additional clock and AXI master port to NoC and connect AI Engines to PS PMC master
      set axi_master_num [get_property CONFIG.NUM_MI $noc]
      set axi_master_name [format "M%02s_AXI" $axi_master_num]
      set pmc_connections [get_property CONFIG.CONNECTIONS [get_bd_intf_pins $noc/S05_AXI]]
      set clk_num [get_property CONFIG.NUM_CLKS $noc]
      set_property CONFIG.NUM_MI [expr $axi_master_num+1] $noc
      set_property CONFIG.NUM_CLKS [expr $clk_num+1] $noc
      set_property CONFIG.CATEGORY {aie} [get_bd_intf_pins $noc/$axi_master_name]
      lappend pmc_connections $axi_master_name {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}
      set_property CONFIG.CONNECTIONS $pmc_connections [get_bd_intf_pins $noc/S05_AXI]

      connect_bd_net $aie_clk [get_bd_pins $noc/aclk$clk_num]
      connect_bd_intf_net [get_bd_intf_pins $noc/$axi_master_name] $axi_aie

      current_bd_instance $old_bd_inst
      return $args
    }

    proc aie_addressmap {{args {}}} {
      set args [lappend args "M_AIE" [list 0x20000000000 0x100000000 0 ""]]
      return $args
    }
  }

  tapasco::register_plugin "platform::versal::connect_aie_engines" "pre-wiring"
  tapasco::register_plugin "platform::versal::aie_addressmap" "post-address-map"
}
