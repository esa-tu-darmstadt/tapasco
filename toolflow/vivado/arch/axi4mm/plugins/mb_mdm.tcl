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

namespace eval mb_mdm {
  set mb_debug_vlnv "xilinx.com:interface:mbdebug_rtl:3.0"
  set mdm_vlnv "xilinx.com:ip:mdm:3.2"

  proc mdm_microblaze {args} {
    variable mb_debug_vlnv
    variable mdm_vlnv
    puts "MicroBlaze: plugin started ..."

    # check if debug module is enabled
    set debug_enabled false
    set fs [tapasco::get_features]
    set fi [lsearch -nocase $fs "microblaze"]
    if {$fi != -1} {
      set f [tapasco::get_feature [lindex $fs $fi]]
      puts "  found MicroBlaze feature: $f"
      if {[dict exists $f "debug"]} {
        set debug_enabled [dict get $f "debug"]
        puts "  MicroBlaze Debug Module (MDM) activated in feature: $debug_enabled"
      }
    }
    puts "  build MDM: $debug_enabled"
    save_bd_design

    if {$debug_enabled} {
      puts "  searching for unconnected MicroBlaze debug ports ..."
      set pins [list]
      foreach p [get_bd_intf_pins -hier -filter "VLNV == $mb_debug_vlnv && MODE == Slave"] {
        if {[llength [get_bd_intf_nets -of_objects $p]] == 0} {
          puts "    found unconnected MicroBlaze debug port: $p"
          lappend pins $p
        }
      }
      set oldInst [current_bd_instance .]
      current_bd_instance [::tapasco::subsystem::get arch]
      set pc [llength $pins]
      if {$pc > 0} {
        puts "  found $pc unconnected MicroBlaze ports, building MDM..."
        set mdm [create_bd_cell -type ip -vlnv $mdm_vlnv mdm]
        set_property -dict [list \
          CONFIG.C_MB_DBG_PORTS $pc \
          CONFIG.C_DBG_REG_ACCESS {1}
        ] $mdm
        for {set i 0} {$i < $pc} {incr i} {
          connect_bd_intf_net [get_bd_intf_pins $mdm/MBDEBUG_$i] [get_bd_intf_pins [lindex $pins $i]]
        }
        connect_bd_net [::tapasco::subsystem::get_port "design" "clk"] [get_bd_pins $mdm/S_AXI_ACLK]
        connect_bd_net [::tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"] [get_bd_pins $mdm/S_AXI_ARESETN]
      } else {
        puts "  found no unconnected MicroBlaze debug ports."
      }

      set clk_pin [get_bd_pins -hier -filter { NAME == design_aclk && DIR == O }]
      set rst_pin [get_bd_pins -hier -filter { NAME == design_peripheral_aresetn && DIR == O }]

      # TODO connect to bus, clk and reset

      current_bd_instance $oldInst
    }
    return $args
  }
}

tapasco::register_plugin "arch::mb_mdm::mdm_microblaze" "post-platform"
