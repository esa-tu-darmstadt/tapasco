#
# Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
  set Page_0 [ipgui::add_page $IPINST -name "Page 0" -display_name {General}]
  #Adding Group
  set Register_Slices [ipgui::add_group $IPINST -name "Register Slices" -parent ${Page_0}]
  set MM_SLICE_ENABLE [ipgui::add_param $IPINST -name "MM_SLICE_ENABLE" -parent ${Register_Slices} -widget comboBox]
  set_property tooltip {0==direct_connection--1==slice_pipeline} ${MM_SLICE_ENABLE}
  set LITE_SLICE_ENABLE [ipgui::add_param $IPINST -name "LITE_SLICE_ENABLE" -parent ${Register_Slices} -widget comboBox]
  set_property tooltip {0==direct_connection--1==slice_pipeline} ${LITE_SLICE_ENABLE}

  #Adding Group
  set Full_AXI4_Settings [ipgui::add_group $IPINST -name "Full AXI4 Settings" -parent ${Page_0}]
  set C_S_AXI_ID_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_ID_WIDTH" -parent ${Full_AXI4_Settings}]
  set_property tooltip {Width of ID for for write address, write data, read address and read data} ${C_S_AXI_ID_WIDTH}
  set C_S_AXI_DATA_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_DATA_WIDTH" -parent ${Full_AXI4_Settings} -widget comboBox]
  set_property tooltip {Width of S_AXI data bus} ${C_S_AXI_DATA_WIDTH}
  set C_S_AXI_ADDR_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_ADDR_WIDTH" -parent ${Full_AXI4_Settings} -widget comboBox]
  set_property tooltip {Width of S_AXI address bus} ${C_S_AXI_ADDR_WIDTH}
  ipgui::add_param $IPINST -name "C_S_AXI_BASEADDR" -parent ${Full_AXI4_Settings}
  ipgui::add_param $IPINST -name "C_S_AXI_HIGHADDR" -parent ${Full_AXI4_Settings}

  #Adding Group
  set AXI4_Lite_Setting [ipgui::add_group $IPINST -name "AXI4 Lite Setting" -parent ${Page_0}]
  set C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR [ipgui::add_param $IPINST -name "C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR" -parent ${AXI4_Lite_Setting}]
  set_property tooltip {The master requires a target slave base address.
    // The master will initiate read and write transactions on the slave with base address specified here as a parameter.} ${C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR}
  set C_M_AXI_LITE_ADDR_WIDTH [ipgui::add_param $IPINST -name "C_M_AXI_LITE_ADDR_WIDTH" -parent ${AXI4_Lite_Setting}]
  set_property tooltip {Width of M_AXI address bus. 
    // The master generates the read and write addresses of width specified as C_M_AXI_ADDR_WIDTH.} ${C_M_AXI_LITE_ADDR_WIDTH}
  set C_M_AXI_LITE_DATA_WIDTH [ipgui::add_param $IPINST -name "C_M_AXI_LITE_DATA_WIDTH" -parent ${AXI4_Lite_Setting} -widget comboBox]
  set_property tooltip {Width of M_AXI data bus.      // The master issues write data and accept read data where the width of the data bus is C_M_AXI_DATA_WIDTH} ${C_M_AXI_LITE_DATA_WIDTH}

  #Adding Group
  set User_Signals [ipgui::add_group $IPINST -name "User Signals" -parent ${Page_0}]
  set C_S_AXI_AWUSER_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_AWUSER_WIDTH" -parent ${User_Signals}]
  set_property tooltip {Width of optional user defined signal in write address channel} ${C_S_AXI_AWUSER_WIDTH}
  set C_S_AXI_ARUSER_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_ARUSER_WIDTH" -parent ${User_Signals}]
  set_property tooltip {Width of optional user defined signal in read address channel} ${C_S_AXI_ARUSER_WIDTH}
  set C_S_AXI_WUSER_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_WUSER_WIDTH" -parent ${User_Signals}]
  set_property tooltip {Width of optional user defined signal in write data channel} ${C_S_AXI_WUSER_WIDTH}
  set C_S_AXI_RUSER_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_RUSER_WIDTH" -parent ${User_Signals}]
  set_property tooltip {Width of optional user defined signal in read data channel} ${C_S_AXI_RUSER_WIDTH}
  set C_S_AXI_BUSER_WIDTH [ipgui::add_param $IPINST -name "C_S_AXI_BUSER_WIDTH" -parent ${User_Signals}]
  set_property tooltip {Width of optional user defined signal in write response channel} ${C_S_AXI_BUSER_WIDTH}


  #Adding Page
  set Page_1 [ipgui::add_page $IPINST -name "Page 1" -display_name {Full AXI4 Slice Settings}]
  #Adding Group
  set Channel_Configuration [ipgui::add_group $IPINST -name "Channel Configuration" -parent ${Page_1} -display_name {Channel Configuration (MM)}]
  set_property tooltip {0==BYPASS--1==FWD_REV--2==FWD--3==REV--4==SLAVE_FWD--5==SLAVE_RDY--6==INPUTS--7==LIGHT_WT} ${Channel_Configuration}
  ipgui::add_param $IPINST -name "MM_CONFIG_AW" -parent ${Channel_Configuration}
  ipgui::add_param $IPINST -name "MM_CONFIG_W" -parent ${Channel_Configuration}
  ipgui::add_param $IPINST -name "MM_CONFIG_B" -parent ${Channel_Configuration}
  ipgui::add_param $IPINST -name "MM_CONFIG_AR" -parent ${Channel_Configuration}
  ipgui::add_param $IPINST -name "MM_CONFIG_R" -parent ${Channel_Configuration}


  #Adding Page
  set Page_2 [ipgui::add_page $IPINST -name "Page 2" -display_name {AXI4-Lite Slice Settings}]
  #Adding Group
  set Channel_Configuration_(Lite) [ipgui::add_group $IPINST -name "Channel Configuration (Lite)" -parent ${Page_2}]
  set_property tooltip {0==BYPASS--1==FWD_REV--2==FWD--3==REV--4==SLAVE_FWD--5==SLAVE_RDY--6==INPUTS--7==LIGHT_WT} ${Channel_Configuration_(Lite)}
  ipgui::add_param $IPINST -name "LITE_CONFIG_AW" -parent ${Channel_Configuration_(Lite)}
  ipgui::add_param $IPINST -name "LITE_CONFIG_W" -parent ${Channel_Configuration_(Lite)}
  ipgui::add_param $IPINST -name "LITE_CONFIG_B" -parent ${Channel_Configuration_(Lite)}
  ipgui::add_param $IPINST -name "LITE_CONFIG_AR" -parent ${Channel_Configuration_(Lite)}
  ipgui::add_param $IPINST -name "LITE_CONFIG_R" -parent ${Channel_Configuration_(Lite)}



}

proc update_PARAM_VALUE.LITE_CONFIG_AR { PARAM_VALUE.LITE_CONFIG_AR } {
	# Procedure called to update LITE_CONFIG_AR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LITE_CONFIG_AR { PARAM_VALUE.LITE_CONFIG_AR } {
	# Procedure called to validate LITE_CONFIG_AR
	return true
}

proc update_PARAM_VALUE.LITE_CONFIG_AW { PARAM_VALUE.LITE_CONFIG_AW } {
	# Procedure called to update LITE_CONFIG_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LITE_CONFIG_AW { PARAM_VALUE.LITE_CONFIG_AW } {
	# Procedure called to validate LITE_CONFIG_AW
	return true
}

proc update_PARAM_VALUE.LITE_CONFIG_B { PARAM_VALUE.LITE_CONFIG_B } {
	# Procedure called to update LITE_CONFIG_B when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LITE_CONFIG_B { PARAM_VALUE.LITE_CONFIG_B } {
	# Procedure called to validate LITE_CONFIG_B
	return true
}

proc update_PARAM_VALUE.LITE_CONFIG_R { PARAM_VALUE.LITE_CONFIG_R } {
	# Procedure called to update LITE_CONFIG_R when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LITE_CONFIG_R { PARAM_VALUE.LITE_CONFIG_R } {
	# Procedure called to validate LITE_CONFIG_R
	return true
}

proc update_PARAM_VALUE.LITE_CONFIG_W { PARAM_VALUE.LITE_CONFIG_W } {
	# Procedure called to update LITE_CONFIG_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LITE_CONFIG_W { PARAM_VALUE.LITE_CONFIG_W } {
	# Procedure called to validate LITE_CONFIG_W
	return true
}

proc update_PARAM_VALUE.LITE_SLICE_ENABLE { PARAM_VALUE.LITE_SLICE_ENABLE } {
	# Procedure called to update LITE_SLICE_ENABLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LITE_SLICE_ENABLE { PARAM_VALUE.LITE_SLICE_ENABLE } {
	# Procedure called to validate LITE_SLICE_ENABLE
	return true
}

proc update_PARAM_VALUE.MM_CONFIG_AR { PARAM_VALUE.MM_CONFIG_AR } {
	# Procedure called to update MM_CONFIG_AR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MM_CONFIG_AR { PARAM_VALUE.MM_CONFIG_AR } {
	# Procedure called to validate MM_CONFIG_AR
	return true
}

proc update_PARAM_VALUE.MM_CONFIG_AW { PARAM_VALUE.MM_CONFIG_AW } {
	# Procedure called to update MM_CONFIG_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MM_CONFIG_AW { PARAM_VALUE.MM_CONFIG_AW } {
	# Procedure called to validate MM_CONFIG_AW
	return true
}

proc update_PARAM_VALUE.MM_CONFIG_B { PARAM_VALUE.MM_CONFIG_B } {
	# Procedure called to update MM_CONFIG_B when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MM_CONFIG_B { PARAM_VALUE.MM_CONFIG_B } {
	# Procedure called to validate MM_CONFIG_B
	return true
}

proc update_PARAM_VALUE.MM_CONFIG_R { PARAM_VALUE.MM_CONFIG_R } {
	# Procedure called to update MM_CONFIG_R when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MM_CONFIG_R { PARAM_VALUE.MM_CONFIG_R } {
	# Procedure called to validate MM_CONFIG_R
	return true
}

proc update_PARAM_VALUE.MM_CONFIG_W { PARAM_VALUE.MM_CONFIG_W } {
	# Procedure called to update MM_CONFIG_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MM_CONFIG_W { PARAM_VALUE.MM_CONFIG_W } {
	# Procedure called to validate MM_CONFIG_W
	return true
}

proc update_PARAM_VALUE.MM_SLICE_ENABLE { PARAM_VALUE.MM_SLICE_ENABLE } {
	# Procedure called to update MM_SLICE_ENABLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MM_SLICE_ENABLE { PARAM_VALUE.MM_SLICE_ENABLE } {
	# Procedure called to validate MM_SLICE_ENABLE
	return true
}

proc update_PARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to update C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to validate C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR
	return true
}

proc update_PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH { PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH } {
	# Procedure called to update C_M_AXI_LITE_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH { PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH } {
	# Procedure called to validate C_M_AXI_LITE_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH { PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH } {
	# Procedure called to update C_M_AXI_LITE_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH { PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH } {
	# Procedure called to validate C_M_AXI_LITE_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ID_WIDTH { PARAM_VALUE.C_S_AXI_ID_WIDTH } {
	# Procedure called to update C_S_AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ID_WIDTH { PARAM_VALUE.C_S_AXI_ID_WIDTH } {
	# Procedure called to validate C_S_AXI_ID_WIDTH
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

proc update_PARAM_VALUE.C_S_AXI_AWUSER_WIDTH { PARAM_VALUE.C_S_AXI_AWUSER_WIDTH } {
	# Procedure called to update C_S_AXI_AWUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_AWUSER_WIDTH { PARAM_VALUE.C_S_AXI_AWUSER_WIDTH } {
	# Procedure called to validate C_S_AXI_AWUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ARUSER_WIDTH { PARAM_VALUE.C_S_AXI_ARUSER_WIDTH } {
	# Procedure called to update C_S_AXI_ARUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ARUSER_WIDTH { PARAM_VALUE.C_S_AXI_ARUSER_WIDTH } {
	# Procedure called to validate C_S_AXI_ARUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_WUSER_WIDTH { PARAM_VALUE.C_S_AXI_WUSER_WIDTH } {
	# Procedure called to update C_S_AXI_WUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_WUSER_WIDTH { PARAM_VALUE.C_S_AXI_WUSER_WIDTH } {
	# Procedure called to validate C_S_AXI_WUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_RUSER_WIDTH { PARAM_VALUE.C_S_AXI_RUSER_WIDTH } {
	# Procedure called to update C_S_AXI_RUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_RUSER_WIDTH { PARAM_VALUE.C_S_AXI_RUSER_WIDTH } {
	# Procedure called to validate C_S_AXI_RUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_BUSER_WIDTH { PARAM_VALUE.C_S_AXI_BUSER_WIDTH } {
	# Procedure called to update C_S_AXI_BUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_BUSER_WIDTH { PARAM_VALUE.C_S_AXI_BUSER_WIDTH } {
	# Procedure called to validate C_S_AXI_BUSER_WIDTH
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


proc update_MODELPARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR { MODELPARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR PARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR}] ${MODELPARAM_VALUE.C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR}
}

proc update_MODELPARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH { MODELPARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH { MODELPARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ID_WIDTH { MODELPARAM_VALUE.C_S_AXI_ID_WIDTH PARAM_VALUE.C_S_AXI_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ID_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_AWUSER_WIDTH { MODELPARAM_VALUE.C_S_AXI_AWUSER_WIDTH PARAM_VALUE.C_S_AXI_AWUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_AWUSER_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_AWUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ARUSER_WIDTH { MODELPARAM_VALUE.C_S_AXI_ARUSER_WIDTH PARAM_VALUE.C_S_AXI_ARUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ARUSER_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ARUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_WUSER_WIDTH { MODELPARAM_VALUE.C_S_AXI_WUSER_WIDTH PARAM_VALUE.C_S_AXI_WUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_WUSER_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_WUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_RUSER_WIDTH { MODELPARAM_VALUE.C_S_AXI_RUSER_WIDTH PARAM_VALUE.C_S_AXI_RUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_RUSER_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_RUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_BUSER_WIDTH { MODELPARAM_VALUE.C_S_AXI_BUSER_WIDTH PARAM_VALUE.C_S_AXI_BUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_BUSER_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_BUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.MM_SLICE_ENABLE { MODELPARAM_VALUE.MM_SLICE_ENABLE PARAM_VALUE.MM_SLICE_ENABLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MM_SLICE_ENABLE}] ${MODELPARAM_VALUE.MM_SLICE_ENABLE}
}

proc update_MODELPARAM_VALUE.MM_CONFIG_AW { MODELPARAM_VALUE.MM_CONFIG_AW PARAM_VALUE.MM_CONFIG_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MM_CONFIG_AW}] ${MODELPARAM_VALUE.MM_CONFIG_AW}
}

proc update_MODELPARAM_VALUE.MM_CONFIG_W { MODELPARAM_VALUE.MM_CONFIG_W PARAM_VALUE.MM_CONFIG_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MM_CONFIG_W}] ${MODELPARAM_VALUE.MM_CONFIG_W}
}

proc update_MODELPARAM_VALUE.MM_CONFIG_B { MODELPARAM_VALUE.MM_CONFIG_B PARAM_VALUE.MM_CONFIG_B } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MM_CONFIG_B}] ${MODELPARAM_VALUE.MM_CONFIG_B}
}

proc update_MODELPARAM_VALUE.MM_CONFIG_AR { MODELPARAM_VALUE.MM_CONFIG_AR PARAM_VALUE.MM_CONFIG_AR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MM_CONFIG_AR}] ${MODELPARAM_VALUE.MM_CONFIG_AR}
}

proc update_MODELPARAM_VALUE.MM_CONFIG_R { MODELPARAM_VALUE.MM_CONFIG_R PARAM_VALUE.MM_CONFIG_R } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MM_CONFIG_R}] ${MODELPARAM_VALUE.MM_CONFIG_R}
}

proc update_MODELPARAM_VALUE.LITE_SLICE_ENABLE { MODELPARAM_VALUE.LITE_SLICE_ENABLE PARAM_VALUE.LITE_SLICE_ENABLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LITE_SLICE_ENABLE}] ${MODELPARAM_VALUE.LITE_SLICE_ENABLE}
}

proc update_MODELPARAM_VALUE.LITE_CONFIG_AW { MODELPARAM_VALUE.LITE_CONFIG_AW PARAM_VALUE.LITE_CONFIG_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LITE_CONFIG_AW}] ${MODELPARAM_VALUE.LITE_CONFIG_AW}
}

proc update_MODELPARAM_VALUE.LITE_CONFIG_W { MODELPARAM_VALUE.LITE_CONFIG_W PARAM_VALUE.LITE_CONFIG_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LITE_CONFIG_W}] ${MODELPARAM_VALUE.LITE_CONFIG_W}
}

proc update_MODELPARAM_VALUE.LITE_CONFIG_B { MODELPARAM_VALUE.LITE_CONFIG_B PARAM_VALUE.LITE_CONFIG_B } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LITE_CONFIG_B}] ${MODELPARAM_VALUE.LITE_CONFIG_B}
}

proc update_MODELPARAM_VALUE.LITE_CONFIG_AR { MODELPARAM_VALUE.LITE_CONFIG_AR PARAM_VALUE.LITE_CONFIG_AR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LITE_CONFIG_AR}] ${MODELPARAM_VALUE.LITE_CONFIG_AR}
}

proc update_MODELPARAM_VALUE.LITE_CONFIG_R { MODELPARAM_VALUE.LITE_CONFIG_R PARAM_VALUE.LITE_CONFIG_R } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LITE_CONFIG_R}] ${MODELPARAM_VALUE.LITE_CONFIG_R}
}

