# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "offset" -parent ${Page_0}
  ipgui::add_param $IPINST -name "offset_bits" -parent ${Page_0}


}

proc update_PARAM_VALUE.offset { PARAM_VALUE.offset } {
	# Procedure called to update offset when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.offset { PARAM_VALUE.offset } {
	# Procedure called to validate offset
	return true
}

proc update_PARAM_VALUE.offset_bits { PARAM_VALUE.offset_bits } {
	# Procedure called to update offset_bits when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.offset_bits { PARAM_VALUE.offset_bits } {
	# Procedure called to validate offset_bits
	return true
}


proc update_MODELPARAM_VALUE.offset { MODELPARAM_VALUE.offset PARAM_VALUE.offset } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.offset}] ${MODELPARAM_VALUE.offset}
}

proc update_MODELPARAM_VALUE.offset_bits { MODELPARAM_VALUE.offset_bits PARAM_VALUE.offset_bits } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.offset_bits}] ${MODELPARAM_VALUE.offset_bits}
}

