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
  namespace eval debug {
    proc versal_debug_hub {{args {}}} {
      set axi_dbg_hub [tapasco::ip::create_axi_dbg_hub dbg_hub]
      set versal_cips [get_bd_cells /*/*cips*]
      set dbg_config [list \
        Clk_master "$versal_cips/pmc_axi_noc_axi0_clk (400 MHz)" \
        Clk_slave {Auto} \
        Clk_xbar {Auto} \
        Master "$versal_cips/PMC_NOC_AXI_0" \
        Slave "$axi_dbg_hub/S_AXI" \
        ddr_seg {Auto} \
        intc_ip {/memory/axi_noc_0} \
        master_apm {0} \
      ]
      apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config $dbg_config [get_bd_intf_pins $axi_dbg_hub/S_AXI]
      return $args
    }
  }

  tapasco::register_plugin "platform::debug::versal_debug_hub" "pre-wrapper"
}
