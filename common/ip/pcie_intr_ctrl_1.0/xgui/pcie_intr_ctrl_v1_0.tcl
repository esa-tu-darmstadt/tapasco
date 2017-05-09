# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "MSI_BIT_WIDTH" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "MSI_VECTOR_WIDTH" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "IRQ_DELAY" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IRQ_TIMEOUT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IRQ_TRIGGERD" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IRQ_RECAP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IRQ_RECAP_CHECK" -parent ${Page_0}


}

proc update_PARAM_VALUE.IRQ_DELAY { PARAM_VALUE.IRQ_DELAY } {
	# Procedure called to update IRQ_DELAY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IRQ_DELAY { PARAM_VALUE.IRQ_DELAY } {
	# Procedure called to validate IRQ_DELAY
	return true
}

proc update_PARAM_VALUE.IRQ_RECAP { PARAM_VALUE.IRQ_RECAP } {
	# Procedure called to update IRQ_RECAP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IRQ_RECAP { PARAM_VALUE.IRQ_RECAP } {
	# Procedure called to validate IRQ_RECAP
	return true
}

proc update_PARAM_VALUE.IRQ_RECAP_CHECK { PARAM_VALUE.IRQ_RECAP_CHECK } {
	# Procedure called to update IRQ_RECAP_CHECK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IRQ_RECAP_CHECK { PARAM_VALUE.IRQ_RECAP_CHECK } {
	# Procedure called to validate IRQ_RECAP_CHECK
	return true
}

proc update_PARAM_VALUE.IRQ_TIMEOUT { PARAM_VALUE.IRQ_TIMEOUT } {
	# Procedure called to update IRQ_TIMEOUT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IRQ_TIMEOUT { PARAM_VALUE.IRQ_TIMEOUT } {
	# Procedure called to validate IRQ_TIMEOUT
	return true
}

proc update_PARAM_VALUE.IRQ_TRIGGERD { PARAM_VALUE.IRQ_TRIGGERD } {
	# Procedure called to update IRQ_TRIGGERD when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IRQ_TRIGGERD { PARAM_VALUE.IRQ_TRIGGERD } {
	# Procedure called to validate IRQ_TRIGGERD
	return true
}

proc update_PARAM_VALUE.MSI_BIT_WIDTH { PARAM_VALUE.MSI_BIT_WIDTH } {
	# Procedure called to update MSI_BIT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MSI_BIT_WIDTH { PARAM_VALUE.MSI_BIT_WIDTH } {
	# Procedure called to validate MSI_BIT_WIDTH
	return true
}

proc update_PARAM_VALUE.MSI_VECTOR_WIDTH { PARAM_VALUE.MSI_VECTOR_WIDTH } {
	# Procedure called to update MSI_VECTOR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MSI_VECTOR_WIDTH { PARAM_VALUE.MSI_VECTOR_WIDTH } {
	# Procedure called to validate MSI_VECTOR_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.MSI_BIT_WIDTH { MODELPARAM_VALUE.MSI_BIT_WIDTH PARAM_VALUE.MSI_BIT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MSI_BIT_WIDTH}] ${MODELPARAM_VALUE.MSI_BIT_WIDTH}
}

proc update_MODELPARAM_VALUE.MSI_VECTOR_WIDTH { MODELPARAM_VALUE.MSI_VECTOR_WIDTH PARAM_VALUE.MSI_VECTOR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MSI_VECTOR_WIDTH}] ${MODELPARAM_VALUE.MSI_VECTOR_WIDTH}
}

proc update_MODELPARAM_VALUE.IRQ_DELAY { MODELPARAM_VALUE.IRQ_DELAY PARAM_VALUE.IRQ_DELAY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IRQ_DELAY}] ${MODELPARAM_VALUE.IRQ_DELAY}
}

proc update_MODELPARAM_VALUE.IRQ_RECAP { MODELPARAM_VALUE.IRQ_RECAP PARAM_VALUE.IRQ_RECAP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IRQ_RECAP}] ${MODELPARAM_VALUE.IRQ_RECAP}
}

proc update_MODELPARAM_VALUE.IRQ_TIMEOUT { MODELPARAM_VALUE.IRQ_TIMEOUT PARAM_VALUE.IRQ_TIMEOUT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IRQ_TIMEOUT}] ${MODELPARAM_VALUE.IRQ_TIMEOUT}
}

proc update_MODELPARAM_VALUE.IRQ_TRIGGERD { MODELPARAM_VALUE.IRQ_TRIGGERD PARAM_VALUE.IRQ_TRIGGERD } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IRQ_TRIGGERD}] ${MODELPARAM_VALUE.IRQ_TRIGGERD}
}

proc update_MODELPARAM_VALUE.IRQ_RECAP_CHECK { MODELPARAM_VALUE.IRQ_RECAP_CHECK PARAM_VALUE.IRQ_RECAP_CHECK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IRQ_RECAP_CHECK}] ${MODELPARAM_VALUE.IRQ_RECAP_CHECK}
}

