# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_AXI_ID_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_AXI_USER_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_CACHELINE_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_CACHELINE_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_MF_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_MF_AXI_BURST_LEN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_MF_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_RAM_TYPE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SF_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SF_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SL_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SL_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_WR_STRATEGY" -parent ${Page_0}


}

proc update_PARAM_VALUE.C_AXI_ID_WIDTH { PARAM_VALUE.C_AXI_ID_WIDTH } {
	# Procedure called to update C_AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXI_ID_WIDTH { PARAM_VALUE.C_AXI_ID_WIDTH } {
	# Procedure called to validate C_AXI_ID_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXI_USER_WIDTH { PARAM_VALUE.C_AXI_USER_WIDTH } {
	# Procedure called to update C_AXI_USER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXI_USER_WIDTH { PARAM_VALUE.C_AXI_USER_WIDTH } {
	# Procedure called to validate C_AXI_USER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_CACHELINE_DATA_WIDTH { PARAM_VALUE.C_CACHELINE_DATA_WIDTH } {
	# Procedure called to update C_CACHELINE_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_CACHELINE_DATA_WIDTH { PARAM_VALUE.C_CACHELINE_DATA_WIDTH } {
	# Procedure called to validate C_CACHELINE_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_CACHELINE_DEPTH { PARAM_VALUE.C_CACHELINE_DEPTH } {
	# Procedure called to update C_CACHELINE_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_CACHELINE_DEPTH { PARAM_VALUE.C_CACHELINE_DEPTH } {
	# Procedure called to validate C_CACHELINE_DEPTH
	return true
}

proc update_PARAM_VALUE.C_MF_AXI_ADDR_WIDTH { PARAM_VALUE.C_MF_AXI_ADDR_WIDTH } {
	# Procedure called to update C_MF_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_MF_AXI_ADDR_WIDTH { PARAM_VALUE.C_MF_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_MF_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_MF_AXI_BURST_LEN { PARAM_VALUE.C_MF_AXI_BURST_LEN } {
	# Procedure called to update C_MF_AXI_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_MF_AXI_BURST_LEN { PARAM_VALUE.C_MF_AXI_BURST_LEN } {
	# Procedure called to validate C_MF_AXI_BURST_LEN
	return true
}

proc update_PARAM_VALUE.C_MF_AXI_DATA_WIDTH { PARAM_VALUE.C_MF_AXI_DATA_WIDTH } {
	# Procedure called to update C_MF_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_MF_AXI_DATA_WIDTH { PARAM_VALUE.C_MF_AXI_DATA_WIDTH } {
	# Procedure called to validate C_MF_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_RAM_TYPE { PARAM_VALUE.C_RAM_TYPE } {
	# Procedure called to update C_RAM_TYPE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_RAM_TYPE { PARAM_VALUE.C_RAM_TYPE } {
	# Procedure called to validate C_RAM_TYPE
	return true
}

proc update_PARAM_VALUE.C_SF_AXI_ADDR_WIDTH { PARAM_VALUE.C_SF_AXI_ADDR_WIDTH } {
	# Procedure called to update C_SF_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SF_AXI_ADDR_WIDTH { PARAM_VALUE.C_SF_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_SF_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_SF_AXI_DATA_WIDTH { PARAM_VALUE.C_SF_AXI_DATA_WIDTH } {
	# Procedure called to update C_SF_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SF_AXI_DATA_WIDTH { PARAM_VALUE.C_SF_AXI_DATA_WIDTH } {
	# Procedure called to validate C_SF_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_SL_AXI_ADDR_WIDTH { PARAM_VALUE.C_SL_AXI_ADDR_WIDTH } {
	# Procedure called to update C_SL_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SL_AXI_ADDR_WIDTH { PARAM_VALUE.C_SL_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_SL_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_SL_AXI_DATA_WIDTH { PARAM_VALUE.C_SL_AXI_DATA_WIDTH } {
	# Procedure called to update C_SL_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SL_AXI_DATA_WIDTH { PARAM_VALUE.C_SL_AXI_DATA_WIDTH } {
	# Procedure called to validate C_SL_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_WR_STRATEGY { PARAM_VALUE.C_WR_STRATEGY } {
	# Procedure called to update C_WR_STRATEGY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_WR_STRATEGY { PARAM_VALUE.C_WR_STRATEGY } {
	# Procedure called to validate C_WR_STRATEGY
	return true
}


proc update_MODELPARAM_VALUE.C_SL_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_SL_AXI_ADDR_WIDTH PARAM_VALUE.C_SL_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SL_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_SL_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_SL_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_SL_AXI_DATA_WIDTH PARAM_VALUE.C_SL_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SL_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_SL_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_SF_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_SF_AXI_ADDR_WIDTH PARAM_VALUE.C_SF_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SF_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_SF_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_SF_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_SF_AXI_DATA_WIDTH PARAM_VALUE.C_SF_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SF_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_SF_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_MF_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_MF_AXI_ADDR_WIDTH PARAM_VALUE.C_MF_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_MF_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_MF_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_MF_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_MF_AXI_DATA_WIDTH PARAM_VALUE.C_MF_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_MF_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_MF_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_MF_AXI_BURST_LEN { MODELPARAM_VALUE.C_MF_AXI_BURST_LEN PARAM_VALUE.C_MF_AXI_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_MF_AXI_BURST_LEN}] ${MODELPARAM_VALUE.C_MF_AXI_BURST_LEN}
}

proc update_MODELPARAM_VALUE.C_AXI_ID_WIDTH { MODELPARAM_VALUE.C_AXI_ID_WIDTH PARAM_VALUE.C_AXI_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXI_ID_WIDTH}] ${MODELPARAM_VALUE.C_AXI_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXI_USER_WIDTH { MODELPARAM_VALUE.C_AXI_USER_WIDTH PARAM_VALUE.C_AXI_USER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXI_USER_WIDTH}] ${MODELPARAM_VALUE.C_AXI_USER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_CACHELINE_DATA_WIDTH { MODELPARAM_VALUE.C_CACHELINE_DATA_WIDTH PARAM_VALUE.C_CACHELINE_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_CACHELINE_DATA_WIDTH}] ${MODELPARAM_VALUE.C_CACHELINE_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_CACHELINE_DEPTH { MODELPARAM_VALUE.C_CACHELINE_DEPTH PARAM_VALUE.C_CACHELINE_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_CACHELINE_DEPTH}] ${MODELPARAM_VALUE.C_CACHELINE_DEPTH}
}

proc update_MODELPARAM_VALUE.C_RAM_TYPE { MODELPARAM_VALUE.C_RAM_TYPE PARAM_VALUE.C_RAM_TYPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_RAM_TYPE}] ${MODELPARAM_VALUE.C_RAM_TYPE}
}

proc update_MODELPARAM_VALUE.C_WR_STRATEGY { MODELPARAM_VALUE.C_WR_STRATEGY PARAM_VALUE.C_WR_STRATEGY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_WR_STRATEGY}] ${MODELPARAM_VALUE.C_WR_STRATEGY}
}

