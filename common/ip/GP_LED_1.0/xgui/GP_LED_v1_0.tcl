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
# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  set Component_Name  [  ipgui::add_param $IPINST -name "Component_Name" -display_name {Component Name}]
  set_property tooltip {Component Name} ${Component_Name}
  #Adding Page
  set page0  [  ipgui::add_page $IPINST -name "page0" -display_name {page0}]
  set_property tooltip {page0} ${page0}
  set LED_WIDTH  [  ipgui::add_param $IPINST -name "LED_WIDTH" -parent ${page0} -display_name {LED_WIDTH} -widget comboBox]
  set_property tooltip {LED_WIDTH} ${LED_WIDTH}


}

proc update_PARAM_VALUE.LED_WIDTH { PARAM_VALUE.LED_WIDTH } {
	# Procedure called to update LED_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LED_WIDTH { PARAM_VALUE.LED_WIDTH } {
	# Procedure called to validate LED_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.LED_WIDTH { MODELPARAM_VALUE.LED_WIDTH PARAM_VALUE.LED_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LED_WIDTH}] ${MODELPARAM_VALUE.LED_WIDTH}
}

