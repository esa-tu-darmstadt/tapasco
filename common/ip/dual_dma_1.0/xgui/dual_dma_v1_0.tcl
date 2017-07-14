# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0" -display_name {General Configuration}]
  ipgui::add_param $IPINST -name "STREAM_ENABLE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DATA_FIFO_MODE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FIFO_SYNC_STAGES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CMD_STS_FIFO_DEPTH" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "DATA_FIFO_DEPTH" -parent ${Page_0} -widget comboBox

  #Adding Page
  set AXI_Slave [ipgui::add_page $IPINST -name "AXI Slave" -display_name {Slave AXI Lite}]
  #Adding Group
  set Slave_Address_Map [ipgui::add_group $IPINST -name "Slave Address Map" -parent ${AXI_Slave} -display_name {Address Map}]
  ipgui::add_param $IPINST -name "C_S_AXI_BASEADDR" -parent ${Slave_Address_Map}
  ipgui::add_param $IPINST -name "C_S_AXI_HIGHADDR" -parent ${Slave_Address_Map}

  #Adding Group
  set Register_Settings [ipgui::add_group $IPINST -name "Register Settings" -parent ${AXI_Slave} -display_name {Settings}]
  ipgui::add_param $IPINST -name "C_S_AXI_DATA_WIDTH" -parent ${Register_Settings}
  ipgui::add_param $IPINST -name "C_S_AXI_ADDR_WIDTH" -parent ${Register_Settings}


  #Adding Page
  set AXI_Master_PCIe [ipgui::add_page $IPINST -name "AXI Master PCIe" -display_name {Master AXI PCIe}]
  #Adding Group
  ipgui::add_group $IPINST -name "Master Address Map" -parent ${AXI_Master_PCIe} -display_name {Address Map}

  #Adding Group
  set MAXI_PCIe_base_settings [ipgui::add_group $IPINST -name "MAXI PCIe base settings" -parent ${AXI_Master_PCIe} -display_name {Base Settings}]
  ipgui::add_param $IPINST -name "M64_IS_ASYNC" -parent ${MAXI_PCIe_base_settings}
  ipgui::add_param $IPINST -name "C_M64_AXI_ADDR_WIDTH" -parent ${MAXI_PCIe_base_settings}
  ipgui::add_param $IPINST -name "C_M64_AXI_DATA_WIDTH" -parent ${MAXI_PCIe_base_settings} -widget comboBox
  ipgui::add_param $IPINST -name "C_M64_AXI_BURST_LEN" -parent ${MAXI_PCIe_base_settings} -widget comboBox
  ipgui::add_param $IPINST -name "M64_READ_MAX_REQ" -parent ${MAXI_PCIe_base_settings}
  ipgui::add_param $IPINST -name "M64_WRITE_MAX_REQ" -parent ${MAXI_PCIe_base_settings}

  #Adding Group
  set MAXI_PCIe_extended_settings [ipgui::add_group $IPINST -name "MAXI PCIe extended settings" -parent ${AXI_Master_PCIe} -display_name {Extended Settings}]
  ipgui::add_param $IPINST -name "C_M64_AXI_ID_WIDTH" -parent ${MAXI_PCIe_extended_settings}
  ipgui::add_param $IPINST -name "C_M64_AXI_ARUSER_WIDTH" -parent ${MAXI_PCIe_extended_settings}
  ipgui::add_param $IPINST -name "C_M64_AXI_RUSER_WIDTH" -parent ${MAXI_PCIe_extended_settings}
  ipgui::add_param $IPINST -name "C_M64_AXI_AWUSER_WIDTH" -parent ${MAXI_PCIe_extended_settings}
  ipgui::add_param $IPINST -name "C_M64_AXI_WUSER_WIDTH" -parent ${MAXI_PCIe_extended_settings}
  ipgui::add_param $IPINST -name "C_M64_AXI_BUSER_WIDTH" -parent ${MAXI_PCIe_extended_settings}


  #Adding Page
  set AXI_Master_User_Logic [ipgui::add_page $IPINST -name "AXI Master User Logic"]
  #Adding Group
  ipgui::add_group $IPINST -name "MAXI User Logic Address Map" -parent ${AXI_Master_User_Logic}

  #Adding Group
  set MAXI_User_Logic_base_settings [ipgui::add_group $IPINST -name "MAXI User Logic base settings" -parent ${AXI_Master_User_Logic} -display_name {Base Settings}]
  ipgui::add_param $IPINST -name "M32_IS_ASYNC" -parent ${MAXI_User_Logic_base_settings}
  ipgui::add_param $IPINST -name "C_M32_AXI_ADDR_WIDTH" -parent ${MAXI_User_Logic_base_settings}
  ipgui::add_param $IPINST -name "C_M32_AXI_DATA_WIDTH" -parent ${MAXI_User_Logic_base_settings} -widget comboBox
  ipgui::add_param $IPINST -name "C_M32_AXI_BURST_LEN" -parent ${MAXI_User_Logic_base_settings} -widget comboBox
  ipgui::add_param $IPINST -name "M32_READ_MAX_REQ" -parent ${MAXI_User_Logic_base_settings}
  ipgui::add_param $IPINST -name "M32_WRITE_MAX_REQ" -parent ${MAXI_User_Logic_base_settings}

  #Adding Group
  set MAXI_User_Logic_extended_settings [ipgui::add_group $IPINST -name "MAXI User Logic extended settings" -parent ${AXI_Master_User_Logic} -display_name {Extended Settings}]
  ipgui::add_param $IPINST -name "C_M32_AXI_ID_WIDTH" -parent ${MAXI_User_Logic_extended_settings}
  ipgui::add_param $IPINST -name "C_M32_AXI_ARUSER_WIDTH" -parent ${MAXI_User_Logic_extended_settings}
  ipgui::add_param $IPINST -name "C_M32_AXI_RUSER_WIDTH" -parent ${MAXI_User_Logic_extended_settings}
  ipgui::add_param $IPINST -name "C_M32_AXI_AWUSER_WIDTH" -parent ${MAXI_User_Logic_extended_settings}
  ipgui::add_param $IPINST -name "C_M32_AXI_WUSER_WIDTH" -parent ${MAXI_User_Logic_extended_settings}
  ipgui::add_param $IPINST -name "C_M32_AXI_BUSER_WIDTH" -parent ${MAXI_User_Logic_extended_settings}


  #Adding Page
  set AXI_Stream_User_Logic [ipgui::add_page $IPINST -name "AXI Stream User Logic"]
  ipgui::add_param $IPINST -name "STR_IS_ASYNC" -parent ${AXI_Stream_User_Logic}
  #Adding Group
  set Slave_Settings [ipgui::add_group $IPINST -name "Slave Settings" -parent ${AXI_Stream_User_Logic}]
  ipgui::add_param $IPINST -name "C_S_AXIS_TDATA_WIDTH" -parent ${Slave_Settings} -widget comboBox
  ipgui::add_param $IPINST -name "C_S_AXIS_BURST_LEN" -parent ${Slave_Settings} -widget comboBox

  #Adding Group
  set Master_Settings [ipgui::add_group $IPINST -name "Master Settings" -parent ${AXI_Stream_User_Logic}]
  ipgui::add_param $IPINST -name "C_M_AXIS_TDATA_WIDTH" -parent ${Master_Settings} -widget comboBox
  ipgui::add_param $IPINST -name "C_M_AXIS_BURST_LEN" -parent ${Master_Settings} -widget comboBox



}

proc update_PARAM_VALUE.CMD_STS_FIFO_DEPTH { PARAM_VALUE.CMD_STS_FIFO_DEPTH } {
	# Procedure called to update CMD_STS_FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CMD_STS_FIFO_DEPTH { PARAM_VALUE.CMD_STS_FIFO_DEPTH } {
	# Procedure called to validate CMD_STS_FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.C_M_AXIS_BURST_LEN { PARAM_VALUE.C_M_AXIS_BURST_LEN } {
	# Procedure called to update C_M_AXIS_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXIS_BURST_LEN { PARAM_VALUE.C_M_AXIS_BURST_LEN } {
	# Procedure called to validate C_M_AXIS_BURST_LEN
	return true
}

proc update_PARAM_VALUE.C_S_AXIS_BURST_LEN { PARAM_VALUE.C_S_AXIS_BURST_LEN } {
	# Procedure called to update C_S_AXIS_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXIS_BURST_LEN { PARAM_VALUE.C_S_AXIS_BURST_LEN } {
	# Procedure called to validate C_S_AXIS_BURST_LEN
	return true
}

proc update_PARAM_VALUE.DATA_FIFO_DEPTH { PARAM_VALUE.DATA_FIFO_DEPTH } {
	# Procedure called to update DATA_FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_FIFO_DEPTH { PARAM_VALUE.DATA_FIFO_DEPTH } {
	# Procedure called to validate DATA_FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.DATA_FIFO_MODE { PARAM_VALUE.DATA_FIFO_MODE } {
	# Procedure called to update DATA_FIFO_MODE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_FIFO_MODE { PARAM_VALUE.DATA_FIFO_MODE } {
	# Procedure called to validate DATA_FIFO_MODE
	return true
}

proc update_PARAM_VALUE.FIFO_SYNC_STAGES { PARAM_VALUE.FIFO_SYNC_STAGES } {
	# Procedure called to update FIFO_SYNC_STAGES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIFO_SYNC_STAGES { PARAM_VALUE.FIFO_SYNC_STAGES } {
	# Procedure called to validate FIFO_SYNC_STAGES
	return true
}

proc update_PARAM_VALUE.M32_IS_ASYNC { PARAM_VALUE.M32_IS_ASYNC } {
	# Procedure called to update M32_IS_ASYNC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.M32_IS_ASYNC { PARAM_VALUE.M32_IS_ASYNC } {
	# Procedure called to validate M32_IS_ASYNC
	return true
}

proc update_PARAM_VALUE.M32_READ_MAX_REQ { PARAM_VALUE.M32_READ_MAX_REQ } {
	# Procedure called to update M32_READ_MAX_REQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.M32_READ_MAX_REQ { PARAM_VALUE.M32_READ_MAX_REQ } {
	# Procedure called to validate M32_READ_MAX_REQ
	return true
}

proc update_PARAM_VALUE.M32_WRITE_MAX_REQ { PARAM_VALUE.M32_WRITE_MAX_REQ } {
	# Procedure called to update M32_WRITE_MAX_REQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.M32_WRITE_MAX_REQ { PARAM_VALUE.M32_WRITE_MAX_REQ } {
	# Procedure called to validate M32_WRITE_MAX_REQ
	return true
}

proc update_PARAM_VALUE.M64_IS_ASYNC { PARAM_VALUE.M64_IS_ASYNC } {
	# Procedure called to update M64_IS_ASYNC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.M64_IS_ASYNC { PARAM_VALUE.M64_IS_ASYNC } {
	# Procedure called to validate M64_IS_ASYNC
	return true
}

proc update_PARAM_VALUE.M64_READ_MAX_REQ { PARAM_VALUE.M64_READ_MAX_REQ } {
	# Procedure called to update M64_READ_MAX_REQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.M64_READ_MAX_REQ { PARAM_VALUE.M64_READ_MAX_REQ } {
	# Procedure called to validate M64_READ_MAX_REQ
	return true
}

proc update_PARAM_VALUE.M64_WRITE_MAX_REQ { PARAM_VALUE.M64_WRITE_MAX_REQ } {
	# Procedure called to update M64_WRITE_MAX_REQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.M64_WRITE_MAX_REQ { PARAM_VALUE.M64_WRITE_MAX_REQ } {
	# Procedure called to validate M64_WRITE_MAX_REQ
	return true
}

proc update_PARAM_VALUE.STREAM_ENABLE { PARAM_VALUE.STREAM_ENABLE } {
	# Procedure called to update STREAM_ENABLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.STREAM_ENABLE { PARAM_VALUE.STREAM_ENABLE } {
	# Procedure called to validate STREAM_ENABLE
	return true
}

proc update_PARAM_VALUE.STR_IS_ASYNC { PARAM_VALUE.STR_IS_ASYNC } {
	# Procedure called to update STR_IS_ASYNC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.STR_IS_ASYNC { PARAM_VALUE.STR_IS_ASYNC } {
	# Procedure called to validate STR_IS_ASYNC
	return true
}

proc update_PARAM_VALUE.C_M_AXIS_TDATA_WIDTH { PARAM_VALUE.C_M_AXIS_TDATA_WIDTH } {
	# Procedure called to update C_M_AXIS_TDATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXIS_TDATA_WIDTH { PARAM_VALUE.C_M_AXIS_TDATA_WIDTH } {
	# Procedure called to validate C_M_AXIS_TDATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXIS_TDATA_WIDTH { PARAM_VALUE.C_S_AXIS_TDATA_WIDTH } {
	# Procedure called to update C_S_AXIS_TDATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXIS_TDATA_WIDTH { PARAM_VALUE.C_S_AXIS_TDATA_WIDTH } {
	# Procedure called to validate C_S_AXIS_TDATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_BURST_LEN { PARAM_VALUE.C_M32_AXI_BURST_LEN } {
	# Procedure called to update C_M32_AXI_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_BURST_LEN { PARAM_VALUE.C_M32_AXI_BURST_LEN } {
	# Procedure called to validate C_M32_AXI_BURST_LEN
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_ID_WIDTH { PARAM_VALUE.C_M32_AXI_ID_WIDTH } {
	# Procedure called to update C_M32_AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_ID_WIDTH { PARAM_VALUE.C_M32_AXI_ID_WIDTH } {
	# Procedure called to validate C_M32_AXI_ID_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_ADDR_WIDTH { PARAM_VALUE.C_M32_AXI_ADDR_WIDTH } {
	# Procedure called to update C_M32_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_ADDR_WIDTH { PARAM_VALUE.C_M32_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_M32_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_DATA_WIDTH { PARAM_VALUE.C_M32_AXI_DATA_WIDTH } {
	# Procedure called to update C_M32_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_DATA_WIDTH { PARAM_VALUE.C_M32_AXI_DATA_WIDTH } {
	# Procedure called to validate C_M32_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_AWUSER_WIDTH { PARAM_VALUE.C_M32_AXI_AWUSER_WIDTH } {
	# Procedure called to update C_M32_AXI_AWUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_AWUSER_WIDTH { PARAM_VALUE.C_M32_AXI_AWUSER_WIDTH } {
	# Procedure called to validate C_M32_AXI_AWUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_ARUSER_WIDTH { PARAM_VALUE.C_M32_AXI_ARUSER_WIDTH } {
	# Procedure called to update C_M32_AXI_ARUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_ARUSER_WIDTH { PARAM_VALUE.C_M32_AXI_ARUSER_WIDTH } {
	# Procedure called to validate C_M32_AXI_ARUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_WUSER_WIDTH { PARAM_VALUE.C_M32_AXI_WUSER_WIDTH } {
	# Procedure called to update C_M32_AXI_WUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_WUSER_WIDTH { PARAM_VALUE.C_M32_AXI_WUSER_WIDTH } {
	# Procedure called to validate C_M32_AXI_WUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_RUSER_WIDTH { PARAM_VALUE.C_M32_AXI_RUSER_WIDTH } {
	# Procedure called to update C_M32_AXI_RUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_RUSER_WIDTH { PARAM_VALUE.C_M32_AXI_RUSER_WIDTH } {
	# Procedure called to validate C_M32_AXI_RUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M32_AXI_BUSER_WIDTH { PARAM_VALUE.C_M32_AXI_BUSER_WIDTH } {
	# Procedure called to update C_M32_AXI_BUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M32_AXI_BUSER_WIDTH { PARAM_VALUE.C_M32_AXI_BUSER_WIDTH } {
	# Procedure called to validate C_M32_AXI_BUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_BURST_LEN { PARAM_VALUE.C_M64_AXI_BURST_LEN } {
	# Procedure called to update C_M64_AXI_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_BURST_LEN { PARAM_VALUE.C_M64_AXI_BURST_LEN } {
	# Procedure called to validate C_M64_AXI_BURST_LEN
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_ID_WIDTH { PARAM_VALUE.C_M64_AXI_ID_WIDTH } {
	# Procedure called to update C_M64_AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_ID_WIDTH { PARAM_VALUE.C_M64_AXI_ID_WIDTH } {
	# Procedure called to validate C_M64_AXI_ID_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_ADDR_WIDTH { PARAM_VALUE.C_M64_AXI_ADDR_WIDTH } {
	# Procedure called to update C_M64_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_ADDR_WIDTH { PARAM_VALUE.C_M64_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_M64_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_DATA_WIDTH { PARAM_VALUE.C_M64_AXI_DATA_WIDTH } {
	# Procedure called to update C_M64_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_DATA_WIDTH { PARAM_VALUE.C_M64_AXI_DATA_WIDTH } {
	# Procedure called to validate C_M64_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_AWUSER_WIDTH { PARAM_VALUE.C_M64_AXI_AWUSER_WIDTH } {
	# Procedure called to update C_M64_AXI_AWUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_AWUSER_WIDTH { PARAM_VALUE.C_M64_AXI_AWUSER_WIDTH } {
	# Procedure called to validate C_M64_AXI_AWUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_ARUSER_WIDTH { PARAM_VALUE.C_M64_AXI_ARUSER_WIDTH } {
	# Procedure called to update C_M64_AXI_ARUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_ARUSER_WIDTH { PARAM_VALUE.C_M64_AXI_ARUSER_WIDTH } {
	# Procedure called to validate C_M64_AXI_ARUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_WUSER_WIDTH { PARAM_VALUE.C_M64_AXI_WUSER_WIDTH } {
	# Procedure called to update C_M64_AXI_WUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_WUSER_WIDTH { PARAM_VALUE.C_M64_AXI_WUSER_WIDTH } {
	# Procedure called to validate C_M64_AXI_WUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_RUSER_WIDTH { PARAM_VALUE.C_M64_AXI_RUSER_WIDTH } {
	# Procedure called to update C_M64_AXI_RUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_RUSER_WIDTH { PARAM_VALUE.C_M64_AXI_RUSER_WIDTH } {
	# Procedure called to validate C_M64_AXI_RUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M64_AXI_BUSER_WIDTH { PARAM_VALUE.C_M64_AXI_BUSER_WIDTH } {
	# Procedure called to update C_M64_AXI_BUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M64_AXI_BUSER_WIDTH { PARAM_VALUE.C_M64_AXI_BUSER_WIDTH } {
	# Procedure called to validate C_M64_AXI_BUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_BASEADDR { PARAM_VALUE.C_S_AXI_BASEADDR } {
	# Procedure called to update C_S_AXI_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_BASEADDR { PARAM_VALUE.C_S_AXI_BASEADDR } {
	# Procedure called to validate C_S_AXI_BASEADDR
	return true
}

proc update_PARAM_VALUE.C_S_AXI_HIGHADDR { PARAM_VALUE.C_S_AXI_HIGHADDR } {
	# Procedure called to update C_S_AXI_HIGHADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_HIGHADDR { PARAM_VALUE.C_S_AXI_HIGHADDR } {
	# Procedure called to validate C_S_AXI_HIGHADDR
	return true
}


proc update_MODELPARAM_VALUE.STREAM_ENABLE { MODELPARAM_VALUE.STREAM_ENABLE PARAM_VALUE.STREAM_ENABLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.STREAM_ENABLE}] ${MODELPARAM_VALUE.STREAM_ENABLE}
}

proc update_MODELPARAM_VALUE.C_M_AXIS_BURST_LEN { MODELPARAM_VALUE.C_M_AXIS_BURST_LEN PARAM_VALUE.C_M_AXIS_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXIS_BURST_LEN}] ${MODELPARAM_VALUE.C_M_AXIS_BURST_LEN}
}

proc update_MODELPARAM_VALUE.C_S_AXIS_BURST_LEN { MODELPARAM_VALUE.C_S_AXIS_BURST_LEN PARAM_VALUE.C_S_AXIS_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXIS_BURST_LEN}] ${MODELPARAM_VALUE.C_S_AXIS_BURST_LEN}
}

proc update_MODELPARAM_VALUE.M64_IS_ASYNC { MODELPARAM_VALUE.M64_IS_ASYNC PARAM_VALUE.M64_IS_ASYNC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.M64_IS_ASYNC}] ${MODELPARAM_VALUE.M64_IS_ASYNC}
}

proc update_MODELPARAM_VALUE.M32_IS_ASYNC { MODELPARAM_VALUE.M32_IS_ASYNC PARAM_VALUE.M32_IS_ASYNC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.M32_IS_ASYNC}] ${MODELPARAM_VALUE.M32_IS_ASYNC}
}

proc update_MODELPARAM_VALUE.STR_IS_ASYNC { MODELPARAM_VALUE.STR_IS_ASYNC PARAM_VALUE.STR_IS_ASYNC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.STR_IS_ASYNC}] ${MODELPARAM_VALUE.STR_IS_ASYNC}
}

proc update_MODELPARAM_VALUE.FIFO_SYNC_STAGES { MODELPARAM_VALUE.FIFO_SYNC_STAGES PARAM_VALUE.FIFO_SYNC_STAGES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIFO_SYNC_STAGES}] ${MODELPARAM_VALUE.FIFO_SYNC_STAGES}
}

proc update_MODELPARAM_VALUE.CMD_STS_FIFO_DEPTH { MODELPARAM_VALUE.CMD_STS_FIFO_DEPTH PARAM_VALUE.CMD_STS_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CMD_STS_FIFO_DEPTH}] ${MODELPARAM_VALUE.CMD_STS_FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.DATA_FIFO_DEPTH { MODELPARAM_VALUE.DATA_FIFO_DEPTH PARAM_VALUE.DATA_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_FIFO_DEPTH}] ${MODELPARAM_VALUE.DATA_FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.DATA_FIFO_MODE { MODELPARAM_VALUE.DATA_FIFO_MODE PARAM_VALUE.DATA_FIFO_MODE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_FIFO_MODE}] ${MODELPARAM_VALUE.DATA_FIFO_MODE}
}

proc update_MODELPARAM_VALUE.M64_READ_MAX_REQ { MODELPARAM_VALUE.M64_READ_MAX_REQ PARAM_VALUE.M64_READ_MAX_REQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.M64_READ_MAX_REQ}] ${MODELPARAM_VALUE.M64_READ_MAX_REQ}
}

proc update_MODELPARAM_VALUE.M64_WRITE_MAX_REQ { MODELPARAM_VALUE.M64_WRITE_MAX_REQ PARAM_VALUE.M64_WRITE_MAX_REQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.M64_WRITE_MAX_REQ}] ${MODELPARAM_VALUE.M64_WRITE_MAX_REQ}
}

proc update_MODELPARAM_VALUE.M32_READ_MAX_REQ { MODELPARAM_VALUE.M32_READ_MAX_REQ PARAM_VALUE.M32_READ_MAX_REQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.M32_READ_MAX_REQ}] ${MODELPARAM_VALUE.M32_READ_MAX_REQ}
}

proc update_MODELPARAM_VALUE.M32_WRITE_MAX_REQ { MODELPARAM_VALUE.M32_WRITE_MAX_REQ PARAM_VALUE.M32_WRITE_MAX_REQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.M32_WRITE_MAX_REQ}] ${MODELPARAM_VALUE.M32_WRITE_MAX_REQ}
}

proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_BURST_LEN { MODELPARAM_VALUE.C_M64_AXI_BURST_LEN PARAM_VALUE.C_M64_AXI_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_BURST_LEN}] ${MODELPARAM_VALUE.C_M64_AXI_BURST_LEN}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_ID_WIDTH { MODELPARAM_VALUE.C_M64_AXI_ID_WIDTH PARAM_VALUE.C_M64_AXI_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_ID_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_M64_AXI_ADDR_WIDTH PARAM_VALUE.C_M64_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_M64_AXI_DATA_WIDTH PARAM_VALUE.C_M64_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_AWUSER_WIDTH { MODELPARAM_VALUE.C_M64_AXI_AWUSER_WIDTH PARAM_VALUE.C_M64_AXI_AWUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_AWUSER_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_AWUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_ARUSER_WIDTH { MODELPARAM_VALUE.C_M64_AXI_ARUSER_WIDTH PARAM_VALUE.C_M64_AXI_ARUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_ARUSER_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_ARUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_WUSER_WIDTH { MODELPARAM_VALUE.C_M64_AXI_WUSER_WIDTH PARAM_VALUE.C_M64_AXI_WUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_WUSER_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_WUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_RUSER_WIDTH { MODELPARAM_VALUE.C_M64_AXI_RUSER_WIDTH PARAM_VALUE.C_M64_AXI_RUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_RUSER_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_RUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M64_AXI_BUSER_WIDTH { MODELPARAM_VALUE.C_M64_AXI_BUSER_WIDTH PARAM_VALUE.C_M64_AXI_BUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M64_AXI_BUSER_WIDTH}] ${MODELPARAM_VALUE.C_M64_AXI_BUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_BURST_LEN { MODELPARAM_VALUE.C_M32_AXI_BURST_LEN PARAM_VALUE.C_M32_AXI_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_BURST_LEN}] ${MODELPARAM_VALUE.C_M32_AXI_BURST_LEN}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_ID_WIDTH { MODELPARAM_VALUE.C_M32_AXI_ID_WIDTH PARAM_VALUE.C_M32_AXI_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_ID_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_M32_AXI_ADDR_WIDTH PARAM_VALUE.C_M32_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_M32_AXI_DATA_WIDTH PARAM_VALUE.C_M32_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_AWUSER_WIDTH { MODELPARAM_VALUE.C_M32_AXI_AWUSER_WIDTH PARAM_VALUE.C_M32_AXI_AWUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_AWUSER_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_AWUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_ARUSER_WIDTH { MODELPARAM_VALUE.C_M32_AXI_ARUSER_WIDTH PARAM_VALUE.C_M32_AXI_ARUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_ARUSER_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_ARUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_WUSER_WIDTH { MODELPARAM_VALUE.C_M32_AXI_WUSER_WIDTH PARAM_VALUE.C_M32_AXI_WUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_WUSER_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_WUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_RUSER_WIDTH { MODELPARAM_VALUE.C_M32_AXI_RUSER_WIDTH PARAM_VALUE.C_M32_AXI_RUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_RUSER_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_RUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M32_AXI_BUSER_WIDTH { MODELPARAM_VALUE.C_M32_AXI_BUSER_WIDTH PARAM_VALUE.C_M32_AXI_BUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M32_AXI_BUSER_WIDTH}] ${MODELPARAM_VALUE.C_M32_AXI_BUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXIS_TDATA_WIDTH { MODELPARAM_VALUE.C_S_AXIS_TDATA_WIDTH PARAM_VALUE.C_S_AXIS_TDATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXIS_TDATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXIS_TDATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M_AXIS_TDATA_WIDTH { MODELPARAM_VALUE.C_M_AXIS_TDATA_WIDTH PARAM_VALUE.C_M_AXIS_TDATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXIS_TDATA_WIDTH}] ${MODELPARAM_VALUE.C_M_AXIS_TDATA_WIDTH}
}

