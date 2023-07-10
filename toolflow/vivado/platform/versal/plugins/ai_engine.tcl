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
    # name for ai engine needs to be exactly like this for xsa export
    set aie [create_bd_cell -type ip -vlnv xilinx.com:ip:ai_engine:2.0 ai_engine_0]
    return $args
  }

  namespace eval versal {
    proc connect_aie_slave {{args {}}} {
      # connect ai_engine_0/S00_AXI to NoC
      # do it after general wiring, so that all other ports of the NoC are already connected
      apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/host/versal_cips_0/pmc_axi_noc_axi0_clk (400 MHz)} Clk_slave {/aie/ai_engine_0/s00_axi_aclk (1250 MHz)} Clk_xbar {Auto} Master {/host/versal_cips_0/PMC_NOC_AXI_0} Slave {/aie/ai_engine_0/S00_AXI} ddr_seg {Auto} intc_ip {/memory/axi_noc_0} master_apm {0}}  [get_bd_intf_pins /aie/ai_engine_0/S00_AXI]


      # revert some strange changes in simulation model selection (bd automation somehow changes it to tlm)
      set_property SELECTED_SIM_MODEL rtl [get_bd_cells /memory/axi_noc_0]

      # rename sub-block interface names for easier identification for address-map creation
      set_property name S_AIE [get_bd_intf_pins /aie/S00_AXI]
      set_property name M_AIE [get_bd_intf_pins /memory/M*_AXI]

      return $args
    }

    proc aie_addressmap {{args {}}} {
      set args [lappend args "M_AIE" [list 0x20000000000 0x100000000 0 ""]]
      return $args
    }
  }

  tapasco::register_plugin "platform::versal::connect_aie_slave" "post-wiring"
  tapasco::register_plugin "platform::versal::aie_addressmap" "post-address-map"
}
