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

    # bypass existing AXI4Lite slaves
    set lite_ports [list]
    set lites [get_bd_intf_pins -of_objects $inst -filter {MODE == Slave && CONFIG.PROTOCOL == AXI4LITE}]
    foreach ls $lites {
      set op [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Slave [get_property NAME $ls]]
      connect_bd_intf_net $op $ls
      lappend lite_ports $ls
    }
    puts "lite_ports = $lite_ports"

    # create master ports
    set maxi_ports [list]
    foreach mp [get_bd_intf_pins -of_objects $inst -filter {MODE == Master}] {
      set op [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Master [get_property NAME $mp]]
      connect_bd_intf_net $mp $op
      lappend maxi_ports $mp
    }
    puts "maxi_ports = $maxi_ports"
    
    # create clock and reset ports
    set clks [get_bd_pins -filter {DIR == I && TYPE == clk} -of_objects [get_bd_cells $bd_inst/*]]
    set rsts [get_bd_pins -filter {DIR == I && TYPE == rst && CONFIG.POLARITY == ACTIVE_LOW} -of_objects [get_bd_cells $bd_inst/*]]
    set clk [create_bd_pin -type clk -dir I "aclk"]
    set rst [create_bd_pin -type rst -dir I "aresetn"]
    
    connect_bd_net $clk $clks
    connect_bd_net $rst $rsts
    
    # create interrupt port
    connect_bd_net [get_bd_pin -of_objects $inst -filter {NAME == interrupt}] [create_bd_pin -type intr -dir O "interrupt"]
    
    return [list $inst $args]
  }

  proc fix_address_map {args} {
    assign_bd_address
    return $args
  }
}

tapasco::register_plugin "arch::full_axi_wrapper::wrap_full_axi_interfaces" "post-pe-create"
tapasco::register_plugin "arch::full_axi_wrapper::fix_address_map" "pre-platform"
