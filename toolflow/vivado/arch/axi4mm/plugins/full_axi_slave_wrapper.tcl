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

namespace eval full_axi_wrapper {
  proc wrap_full_axi_interfaces {inst {args {}}} {

    # check interfaces: AXI3/AXI4 slaves will be wrappped
    set inst [get_bd_cells $inst]
    set full_slave_ifs [get_bd_intf_pins -of_objects $inst -filter {MODE == Slave && (CONFIG.PROTOCOL == AXI3 || CONFIG.PROTOCOL == AXI4)}]
    if {[llength $full_slave_ifs] > 0} {
      puts "  IP has full slaves, will add protocol converter"
      puts "  found full slave interfaces: $full_slave_ifs"
    }
    set name [get_property NAME $inst]

    set bd_inst [current_bd_instance .]


    if {![tapasco::get_feature_option "WrapAXIFull" "enabled" true]} {
      foreach fs $full_slave_ifs {
        set op [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Slave [get_property NAME $fs]]
        connect_bd_intf_net $op $fs
      }
    } else {

      # rewire full slaves
      set si 0
      foreach fs $full_slave_ifs {
        # create slave port
        set saxi_port [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Slave "S_AXI_LITE_$si"]
        set conv [tapasco::ip::create_proto_conv "conv_$si" "AXI4LITE" [get_property CONFIG.PROTOCOL $fs]]
        connect_bd_intf_net $saxi_port [get_bd_intf_pins -of_objects $conv -filter {MODE == Slave}]
        connect_bd_intf_net [get_bd_intf_pins -filter {MODE == Master} -of_objects $conv] $fs

        incr si
      }

    }

    
    return [list $inst $args]
  }

  proc fix_address_map {args} {
    assign_bd_address
    return $args
  }
}

tapasco::register_plugin "arch::full_axi_wrapper::wrap_full_axi_interfaces" "post-pe-create"
tapasco::register_plugin "arch::full_axi_wrapper::fix_address_map" "pre-platform"
