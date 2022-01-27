# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "mac_addr" -parent ${Page_0}


}

proc update_PARAM_VALUE.mac_addr { PARAM_VALUE.mac_addr } {
	# Procedure called to update mac_addr when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.mac_addr { PARAM_VALUE.mac_addr } {
	# Procedure called to validate mac_addr
	return true
}


proc update_MODELPARAM_VALUE.mac_addr { MODELPARAM_VALUE.mac_addr PARAM_VALUE.mac_addr } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.mac_addr}] ${MODELPARAM_VALUE.mac_addr}
}

