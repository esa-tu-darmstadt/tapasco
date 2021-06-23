# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DEST_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "USER_OVERWRITE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "USER_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.DEST_WIDTH { PARAM_VALUE.DEST_WIDTH } {
	# Procedure called to update DEST_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEST_WIDTH { PARAM_VALUE.DEST_WIDTH } {
	# Procedure called to validate DEST_WIDTH
	return true
}

proc update_PARAM_VALUE.USER_OVERWRITE { PARAM_VALUE.USER_OVERWRITE } {
	# Procedure called to update USER_OVERWRITE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.USER_OVERWRITE { PARAM_VALUE.USER_OVERWRITE } {
	# Procedure called to validate USER_OVERWRITE
	return true
}

proc update_PARAM_VALUE.USER_WIDTH { PARAM_VALUE.USER_WIDTH } {
	# Procedure called to update USER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.USER_WIDTH { PARAM_VALUE.USER_WIDTH } {
	# Procedure called to validate USER_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.USER_OVERWRITE { MODELPARAM_VALUE.USER_OVERWRITE PARAM_VALUE.USER_OVERWRITE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.USER_OVERWRITE}] ${MODELPARAM_VALUE.USER_OVERWRITE}
}

proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.USER_WIDTH { MODELPARAM_VALUE.USER_WIDTH PARAM_VALUE.USER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.USER_WIDTH}] ${MODELPARAM_VALUE.USER_WIDTH}
}

proc update_MODELPARAM_VALUE.DEST_WIDTH { MODELPARAM_VALUE.DEST_WIDTH PARAM_VALUE.DEST_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEST_WIDTH}] ${MODELPARAM_VALUE.DEST_WIDTH}
}

