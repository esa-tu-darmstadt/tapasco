# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "host_ddr" -parent ${Page_0}
  ipgui::add_param $IPINST -name "pcie_nvme_base_address" -parent ${Page_0}


}

proc update_PARAM_VALUE.host_ddr { PARAM_VALUE.host_ddr } {
	# Procedure called to update host_ddr when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.host_ddr { PARAM_VALUE.host_ddr } {
	# Procedure called to validate host_ddr
	return true
}

proc update_PARAM_VALUE.pcie_nvme_base_address { PARAM_VALUE.pcie_nvme_base_address } {
	# Procedure called to update pcie_nvme_base_address when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.pcie_nvme_base_address { PARAM_VALUE.pcie_nvme_base_address } {
	# Procedure called to validate pcie_nvme_base_address
	return true
}


proc update_MODELPARAM_VALUE.pcie_nvme_base_address { MODELPARAM_VALUE.pcie_nvme_base_address PARAM_VALUE.pcie_nvme_base_address } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.pcie_nvme_base_address}] ${MODELPARAM_VALUE.pcie_nvme_base_address}
}

proc update_MODELPARAM_VALUE.host_ddr { MODELPARAM_VALUE.host_ddr PARAM_VALUE.host_ddr } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.host_ddr}] ${MODELPARAM_VALUE.host_ddr}
}

