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
if {[tapasco::is_feature_enabled "OLED"]} {
  # Creates the optional OLED controller indicating interrupts.
  # @param ps Processing System instance
  proc create_custom_subsystem_oled {} {
    # number of INTC's
    set irqs [::arch::get_irqs]
    set no_intcs [llength $irqs]

    # create OLED controller
    set oled_ctrl [tapasco::ip::create_oled_ctrl oled_ctrl]

    # create ports
    set initialized [create_bd_port -dir O "initialized"]
    set heartbeat [create_bd_port -dir O "heartbeat"]
    set op_cc [tapasco::ip::create_xlconcat "op_cc" $no_intcs]
    connect_bd_net [get_bd_pins -of_objects $op_cc -filter { DIR == "O" }] [get_bd_pins $oled_ctrl/intr]
    for {set i 0} {$i < $no_intcs} {incr i} {
      connect_bd_net [lindex $irqs $i] [get_bd_pins "$op_cc/In$i"]
    }

    # create clock
    set clk_wiz [::tapasco::ip::create_clk_wiz "clk_wiz"]
    set_property -dict [list \
      CONFIG.USE_LOCKED {false} \
      CONFIG.USE_RESET {false} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {10.000} \
    ] $clk_wiz
    connect_bd_net [tapasco::subsystem::get_port "host" "clk"] \
      [get_bd_pins -of_objects $clk_wiz -filter { TYPE == clk && DIR == I }]
    connect_bd_net [get_bd_pins -of_objects $clk_wiz -filter { TYPE == clk && DIR == O }] \
      [get_bd_pins -of_objects $oled_ctrl -filter { TYPE == clk && DIR == I }]

    # connect reset
    connect_bd_net [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"] \
      [get_bd_pins $oled_ctrl/rst_n]

    # create external port 'oled'
    set op [create_bd_intf_port -mode "master" -vlnv "esa.cs.tu-darmstadt.de:user:oled_rtl:1.0" "oled"]
    connect_bd_intf_net [get_bd_intf_pins -of_objects $oled_ctrl] $op
    connect_bd_net [get_bd_pins $oled_ctrl/initialized] $initialized
    connect_bd_net [get_bd_pins $oled_ctrl/heartbeat] $heartbeat
  }
}
