#
# Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
set_property PACKAGE_PIN AM39 [get_ports {LED_Port[0]}]
set_property PACKAGE_PIN AN39 [get_ports {LED_Port[1]}]
set_property PACKAGE_PIN AR37 [get_ports {LED_Port[2]}]
set_property PACKAGE_PIN AT37 [get_ports {LED_Port[3]}]
set_property PACKAGE_PIN AR35 [get_ports {LED_Port[4]}]
set_property PACKAGE_PIN AP41 [get_ports {LED_Port[5]}]
set_property PACKAGE_PIN AP42 [get_ports {LED_Port[6]}]
set_property PACKAGE_PIN AU39 [get_ports {LED_Port[7]}]

set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_Port[7]}]

set_property SLEW SLOW [get_ports {LED_Port[7]}]
set_property SLEW SLOW [get_ports {LED_Port[6]}]
set_property SLEW SLOW [get_ports {LED_Port[5]}]
set_property SLEW SLOW [get_ports {LED_Port[4]}]
set_property SLEW SLOW [get_ports {LED_Port[3]}]
set_property SLEW SLOW [get_ports {LED_Port[2]}]
set_property SLEW SLOW [get_ports {LED_Port[1]}]
set_property SLEW SLOW [get_ports {LED_Port[0]}]
set_property DRIVE 4 [get_ports {LED_Port[7]}]
set_property DRIVE 4 [get_ports {LED_Port[6]}]
set_property DRIVE 4 [get_ports {LED_Port[5]}]
set_property DRIVE 4 [get_ports {LED_Port[4]}]
set_property DRIVE 4 [get_ports {LED_Port[3]}]
set_property DRIVE 4 [get_ports {LED_Port[2]}]
set_property DRIVE 4 [get_ports {LED_Port[1]}]
set_property DRIVE 4 [get_ports {LED_Port[0]}]
