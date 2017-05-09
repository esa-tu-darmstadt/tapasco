#
# Copyright (C) 2014 Jens Korinth, TU Darmstadt
#
# This file is part of Tapasco (TPC).
#
# Tapasco is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Tapasco is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
#
# @file   full_axi_slave_wrapper.tcl
# @brief  PE-wrapper plugin that checks for full AXI3/4 slave protocols and
#         wraps them with a AXI protocol converter to AXI4Lite (if any).
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval full_axi_wrapper {
  proc wrap_full_axi_interfaces {inst {args {}}} {
    # check interfaces: AXI3/AXI4 slaves will be wrappped
    set inst [get_bd_cells $inst]
    set full_slave_ifs [get_bd_intf_pins -of_objects $inst -filter {MODE == Slave && (CONFIG.PROTOCOL == AXI3 || CONFIG.PROTOCOL == AXI4)}]
    if {[llength $full_slave_ifs] > 1} { error "full_axi_wrapper plugin: Found [llength $full_slave_ifs] full slave interfaces, this is not supported at the moment" }
    if {[llength $full_slave_ifs] > 0} {
      puts "  IP has full slaves, will add protocol converter"
      puts "  found full slave interfaces: $full_slave_ifs"
      set name [get_property NAME $inst]
    
      set bd_inst [current_bd_instance .]
      # create group, move instance into group
      set_property NAME "internal_$name" $inst
      set group [create_bd_cell -type hier $name]
      move_bd_cells $group $inst
      set ninst [get_bd_cells $group/internal_$name]
      current_bd_instance $group
    
      # create slave ports
      set saxi_port [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Slave "S_AXI_LITE"]
      set conv [tapasco::createProtocolConverter "conv" "AXI4LITE" [get_property CONFIG.PROTOCOL $full_slave_ifs]]
      connect_bd_intf_net $saxi_port [get_bd_intf_pins -of_objects $conv -filter {MODE == Slave}]
      connect_bd_intf_net [get_bd_intf_pins -filter {MODE == Master} -of_objects $conv] $full_slave_ifs
    
      # create master ports
      set maxi_ports [list]
      foreach mp [get_bd_intf_pins -of_objects $ninst -filter {MODE == Master}] {
        set op [create_bd_intf_pin -vlnv "xilinx.com:interface:aximm_rtl:1.0" -mode Master [get_property NAME $mp]]
        connect_bd_intf_net $mp $op
        lappend maxi_ports $mp
      }
      puts "maxi_ports = $maxi_ports"
    
      # create clock and reset ports
      set clks [get_bd_pins -filter {DIR == I && TYPE == clk} -of_objects [get_bd_cells $group/*]]
      set rsts [get_bd_pins -filter {DIR == I && TYPE == rst} -of_objects [get_bd_cells $group/*]]
      set clk [create_bd_pin -type clk -dir I "aclk"]
      set rst [create_bd_pin -type rst -dir I "aresetn"]
    
      connect_bd_net $clk $clks
      connect_bd_net $rst $rsts
    
      # create interrupt port
      connect_bd_net [get_bd_pin -of_objects $ninst -filter {NAME == interrupt}] [create_bd_pin -type intr -dir O "interrupt"]
    
      current_bd_instance $bd_inst
      return [list $group $args]
    }
    return [list $inst $args]
  }
}

tapasco::register_plugin "arch::full_axi_wrapper::wrap_full_axi_interfaces" "post-pe-create"
