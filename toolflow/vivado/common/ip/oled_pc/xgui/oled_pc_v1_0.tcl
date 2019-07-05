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
# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_COLS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_COUNTER_N" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_COUNTER_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_ROWS" -parent ${Page_0}

  set C_DELAY_1MS [ipgui::add_param $IPINST -name "C_DELAY_1MS"]
  set_property tooltip {Number of clock cycles in 1ms} ${C_DELAY_1MS}

}

proc update_PARAM_VALUE.C_COLS { PARAM_VALUE.C_COLS } {
	# Procedure called to update C_COLS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_COLS { PARAM_VALUE.C_COLS } {
	# Procedure called to validate C_COLS
	return true
}

proc update_PARAM_VALUE.C_COUNTER_N { PARAM_VALUE.C_COUNTER_N } {
	# Procedure called to update C_COUNTER_N when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_COUNTER_N { PARAM_VALUE.C_COUNTER_N } {
	# Procedure called to validate C_COUNTER_N
	return true
}

proc update_PARAM_VALUE.C_COUNTER_W { PARAM_VALUE.C_COUNTER_W } {
	# Procedure called to update C_COUNTER_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_COUNTER_W { PARAM_VALUE.C_COUNTER_W } {
	# Procedure called to validate C_COUNTER_W
	return true
}

proc update_PARAM_VALUE.C_DELAY_1MS { PARAM_VALUE.C_DELAY_1MS } {
	# Procedure called to update C_DELAY_1MS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_DELAY_1MS { PARAM_VALUE.C_DELAY_1MS } {
	# Procedure called to validate C_DELAY_1MS
	return true
}

proc update_PARAM_VALUE.C_ROWS { PARAM_VALUE.C_ROWS } {
	# Procedure called to update C_ROWS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_ROWS { PARAM_VALUE.C_ROWS } {
	# Procedure called to validate C_ROWS
	return true
}


proc update_MODELPARAM_VALUE.C_COUNTER_N { MODELPARAM_VALUE.C_COUNTER_N PARAM_VALUE.C_COUNTER_N } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_COUNTER_N}] ${MODELPARAM_VALUE.C_COUNTER_N}
}

proc update_MODELPARAM_VALUE.C_COUNTER_W { MODELPARAM_VALUE.C_COUNTER_W PARAM_VALUE.C_COUNTER_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_COUNTER_W}] ${MODELPARAM_VALUE.C_COUNTER_W}
}

proc update_MODELPARAM_VALUE.C_COLS { MODELPARAM_VALUE.C_COLS PARAM_VALUE.C_COLS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_COLS}] ${MODELPARAM_VALUE.C_COLS}
}

proc update_MODELPARAM_VALUE.C_ROWS { MODELPARAM_VALUE.C_ROWS PARAM_VALUE.C_ROWS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_ROWS}] ${MODELPARAM_VALUE.C_ROWS}
}

proc update_MODELPARAM_VALUE.C_DELAY_1MS { MODELPARAM_VALUE.C_DELAY_1MS PARAM_VALUE.C_DELAY_1MS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_DELAY_1MS}] ${MODELPARAM_VALUE.C_DELAY_1MS}
}

