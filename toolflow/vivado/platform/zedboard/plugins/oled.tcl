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

if {[tapasco::is_feature_enabled "OLED"]} {
  # Creates the optional OLED controller indicating interrupts.
  # @param ps Processing System instance
  proc create_custom_subsystem_oled {} {
    # create OLED controller
    set oled_ctrl [tapasco::ip::create_oled_ctrl oled_ctrl]

    # create ports
    set initialized [create_bd_port -dir O "initialized"]
    set heartbeat [create_bd_port -dir O "heartbeat"]

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
