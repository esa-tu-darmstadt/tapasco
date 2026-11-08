# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "IPI_CHANNEL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TIMEOUT_CYCLES" -parent ${Page_0}


}

proc update_PARAM_VALUE.IPI_CHANNEL { PARAM_VALUE.IPI_CHANNEL } {
	# Procedure called to update IPI_CHANNEL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IPI_CHANNEL { PARAM_VALUE.IPI_CHANNEL } {
	# Procedure called to validate IPI_CHANNEL
	return true
}

proc update_PARAM_VALUE.TIMEOUT_CYCLES { PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to update TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TIMEOUT_CYCLES { PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to validate TIMEOUT_CYCLES
	return true
}


proc update_MODELPARAM_VALUE.IPI_CHANNEL { MODELPARAM_VALUE.IPI_CHANNEL PARAM_VALUE.IPI_CHANNEL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IPI_CHANNEL}] ${MODELPARAM_VALUE.IPI_CHANNEL}
}

proc update_MODELPARAM_VALUE.TIMEOUT_CYCLES { MODELPARAM_VALUE.TIMEOUT_CYCLES PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.TIMEOUT_CYCLES}
}

