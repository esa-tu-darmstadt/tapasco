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
# @file   oled.tcl
# @brief  Plugin to add a OLED display driver that shows the occurrence and
#         counts of interrupts at each slot graphically.
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval oled {
  # Creates the optional OLED controller indicating interrupts.
  # @param ps Processing System instance
  proc create_subsystem_oled {name irqs} {
    # number of INTC's
    set no_intcs [llength $irqs]
    # make new group for OLED
    set instance [current_bd_instance .]
    set group [create_bd_cell -type hier $name]
    current_bd_instance $group

    # create OLED controller
    set oled_ctrl [tapasco::createOLEDController oled_ctrl]

    # create ports
    set clk [create_bd_pin -type "clk" -dir I "aclk"]
    set rst [create_bd_pin -type "rst" -dir I "peripheral_aresetn"]
    set initialized [create_bd_port -dir O "initialized"]
    set heartbeat [create_bd_port -dir O "heartbeat"]
    set op_cc [tapasco::createConcat "op_cc" $no_intcs]
    connect_bd_net [get_bd_pins -of_objects $op_cc -filter { DIR == "O" }] [get_bd_pins $oled_ctrl/intr]
    for {set i 0} {$i < $no_intcs} {incr i} {
      connect_bd_net [lindex $irqs $i] [get_bd_pins "$op_cc/In$i"]
    }

    # connect clock port
    connect_bd_net $clk [get_bd_pins -of_objects $oled_ctrl -filter { TYPE == "clk" && DIR == "I" }]

    # connect reset
    connect_bd_net $rst [get_bd_pins $oled_ctrl/rst_n]

    # create external port 'oled'
    set op [create_bd_intf_port -mode "master" -vlnv "esa.cs.tu-darmstadt.de:user:oled_rtl:1.0" "oled"]
    connect_bd_intf_net [get_bd_intf_pins -of_objects $oled_ctrl] $op
    connect_bd_net [get_bd_pins $oled_ctrl/initialized] $initialized
    connect_bd_net [get_bd_pins $oled_ctrl/heartbeat] $heartbeat

    current_bd_instance $instance
    return $group
  }

  proc oled_feature {{args {}}} {
    if {[tapasco::is_platform_feature_enabled "OLED"]} {
      set oled [create_subsystem_oled "OLED" [arch::get_irqs]]
      set ps [get_bd_cell -hierarchical -filter {VLNV =~ "xilinx.com:ip:processing_system*"}]
      set ps_rst [get_bd_pin "/Host/ps_resetn"]

      set cnr_oled [tapasco::create_subsystem_clocks_and_resets [list "oled" 10] "OLED_ClockReset"]
      connect_bd_net $ps_rst [get_bd_pins -filter {TYPE == rst && DIR == I} -of_objects $cnr_oled]
      set clk [get_bd_pins -filter {TYPE == clk && DIR == O} -of_objects $cnr_oled]
      set rst [get_bd_pins "$cnr_oled/oled_peripheral_aresetn"]

      connect_bd_net $clk [get_bd_pins "$oled/aclk"]
      connect_bd_net $rst [get_bd_pins "$oled/peripheral_aresetn"]
    }
    return {}
  }
}

tapasco::register_plugin "platform::oled::oled_feature" "post-bd"
