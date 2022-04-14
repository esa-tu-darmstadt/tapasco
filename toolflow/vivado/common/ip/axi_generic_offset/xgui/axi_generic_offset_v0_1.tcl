# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ADDRESS_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BYTES_PER_WORD" -parent ${Page_0}
  ipgui::add_param $IPINST -name "HIGHEST_ADDR_BIT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ID_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "OVERWRITE_BITS" -parent ${Page_0}


}

proc update_PARAM_VALUE.ADDRESS_WIDTH { PARAM_VALUE.ADDRESS_WIDTH } {
	# Procedure called to update ADDRESS_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ADDRESS_WIDTH { PARAM_VALUE.ADDRESS_WIDTH } {
	# Procedure called to validate ADDRESS_WIDTH
	return true
}

proc update_PARAM_VALUE.BYTES_PER_WORD { PARAM_VALUE.BYTES_PER_WORD } {
	# Procedure called to update BYTES_PER_WORD when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BYTES_PER_WORD { PARAM_VALUE.BYTES_PER_WORD } {
	# Procedure called to validate BYTES_PER_WORD
	return true
}

proc update_PARAM_VALUE.HIGHEST_ADDR_BIT { PARAM_VALUE.HIGHEST_ADDR_BIT } {
	# Procedure called to update HIGHEST_ADDR_BIT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HIGHEST_ADDR_BIT { PARAM_VALUE.HIGHEST_ADDR_BIT } {
	# Procedure called to validate HIGHEST_ADDR_BIT
	return true
}

proc update_PARAM_VALUE.ID_WIDTH { PARAM_VALUE.ID_WIDTH } {
	# Procedure called to update ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ID_WIDTH { PARAM_VALUE.ID_WIDTH } {
	# Procedure called to validate ID_WIDTH
	return true
}

proc update_PARAM_VALUE.OVERWRITE_BITS { PARAM_VALUE.OVERWRITE_BITS } {
	# Procedure called to update OVERWRITE_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.OVERWRITE_BITS { PARAM_VALUE.OVERWRITE_BITS } {
	# Procedure called to validate OVERWRITE_BITS
	return true
}


proc update_MODELPARAM_VALUE.BYTES_PER_WORD { MODELPARAM_VALUE.BYTES_PER_WORD PARAM_VALUE.BYTES_PER_WORD } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BYTES_PER_WORD}] ${MODELPARAM_VALUE.BYTES_PER_WORD}
}

proc update_MODELPARAM_VALUE.ADDRESS_WIDTH { MODELPARAM_VALUE.ADDRESS_WIDTH PARAM_VALUE.ADDRESS_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADDRESS_WIDTH}] ${MODELPARAM_VALUE.ADDRESS_WIDTH}
}

proc update_MODELPARAM_VALUE.ID_WIDTH { MODELPARAM_VALUE.ID_WIDTH PARAM_VALUE.ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ID_WIDTH}] ${MODELPARAM_VALUE.ID_WIDTH}
}

proc update_MODELPARAM_VALUE.OVERWRITE_BITS { MODELPARAM_VALUE.OVERWRITE_BITS PARAM_VALUE.OVERWRITE_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.OVERWRITE_BITS}] ${MODELPARAM_VALUE.OVERWRITE_BITS}
}

proc update_MODELPARAM_VALUE.HIGHEST_ADDR_BIT { MODELPARAM_VALUE.HIGHEST_ADDR_BIT PARAM_VALUE.HIGHEST_ADDR_BIT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HIGHEST_ADDR_BIT}] ${MODELPARAM_VALUE.HIGHEST_ADDR_BIT}
}

