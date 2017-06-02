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
# set constraints to OLED pins on zedboard
set_property PACKAGE_PIN U12 [get_ports oled_oled_vdd]
set_property PACKAGE_PIN U11 [get_ports oled_oled_vbat]
set_property PACKAGE_PIN U9 [get_ports oled_oled_res]
set_property PACKAGE_PIN U10 [get_ports oled_oled_dc]
set_property PACKAGE_PIN AB12 [get_ports oled_oled_sclk]
set_property PACKAGE_PIN AA12 [get_ports oled_oled_sdin]
set_property IOSTANDARD LVCMOS33 [get_ports oled_oled_vdd]
set_property IOSTANDARD LVCMOS33 [get_ports oled_oled_vbat]
set_property IOSTANDARD LVCMOS33 [get_ports oled_oled_res]
set_property IOSTANDARD LVCMOS33 [get_ports oled_oled_dc]
set_property IOSTANDARD LVCMOS33 [get_ports oled_oled_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports oled_oled_sdin]

set_property PACKAGE_PIN T22 [get_ports heartbeat]
set_property PACKAGE_PIN T21 [get_ports initialized]
set_property IOSTANDARD LVCMOS33 [get_ports initialized]
set_property IOSTANDARD LVCMOS33 [get_ports heartbeat]
