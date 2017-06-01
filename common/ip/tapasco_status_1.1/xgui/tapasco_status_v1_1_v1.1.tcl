# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_CAPABILITIES_0" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_INTC_COUNT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S00_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S00_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_1" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_10" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_100" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_101" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_102" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_103" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_104" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_105" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_106" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_107" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_108" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_109" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_11" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_110" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_111" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_112" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_113" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_114" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_115" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_116" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_117" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_118" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_119" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_12" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_120" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_121" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_122" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_123" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_124" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_125" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_126" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_127" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_128" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_13" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_14" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_15" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_16" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_17" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_18" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_19" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_2" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_20" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_21" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_22" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_23" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_24" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_25" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_26" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_27" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_28" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_29" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_3" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_30" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_31" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_32" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_33" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_34" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_35" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_36" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_37" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_38" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_39" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_4" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_40" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_41" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_42" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_43" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_44" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_45" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_46" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_47" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_48" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_49" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_5" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_50" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_51" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_52" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_53" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_54" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_55" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_56" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_57" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_58" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_59" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_6" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_60" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_61" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_62" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_63" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_64" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_65" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_66" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_67" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_68" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_69" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_7" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_70" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_71" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_72" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_73" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_74" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_75" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_76" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_77" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_78" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_79" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_8" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_80" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_81" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_82" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_83" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_84" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_85" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_86" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_87" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_88" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_89" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_9" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_90" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_91" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_92" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_93" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_94" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_95" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_96" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_97" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_98" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SLOT_KERNEL_ID_99" -parent ${Page_0}


}

proc update_PARAM_VALUE.C_CAPABILITIES_0 { PARAM_VALUE.C_CAPABILITIES_0 } {
	# Procedure called to update C_CAPABILITIES_0 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_CAPABILITIES_0 { PARAM_VALUE.C_CAPABILITIES_0 } {
	# Procedure called to validate C_CAPABILITIES_0
	return true
}

proc update_PARAM_VALUE.C_INTC_COUNT { PARAM_VALUE.C_INTC_COUNT } {
	# Procedure called to update C_INTC_COUNT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_INTC_COUNT { PARAM_VALUE.C_INTC_COUNT } {
	# Procedure called to validate C_INTC_COUNT
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S00_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S00_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to update C_S00_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S00_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_1 { PARAM_VALUE.C_SLOT_KERNEL_ID_1 } {
	# Procedure called to update C_SLOT_KERNEL_ID_1 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_1 { PARAM_VALUE.C_SLOT_KERNEL_ID_1 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_1
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_10 { PARAM_VALUE.C_SLOT_KERNEL_ID_10 } {
	# Procedure called to update C_SLOT_KERNEL_ID_10 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_10 { PARAM_VALUE.C_SLOT_KERNEL_ID_10 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_10
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_100 { PARAM_VALUE.C_SLOT_KERNEL_ID_100 } {
	# Procedure called to update C_SLOT_KERNEL_ID_100 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_100 { PARAM_VALUE.C_SLOT_KERNEL_ID_100 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_100
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_101 { PARAM_VALUE.C_SLOT_KERNEL_ID_101 } {
	# Procedure called to update C_SLOT_KERNEL_ID_101 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_101 { PARAM_VALUE.C_SLOT_KERNEL_ID_101 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_101
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_102 { PARAM_VALUE.C_SLOT_KERNEL_ID_102 } {
	# Procedure called to update C_SLOT_KERNEL_ID_102 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_102 { PARAM_VALUE.C_SLOT_KERNEL_ID_102 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_102
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_103 { PARAM_VALUE.C_SLOT_KERNEL_ID_103 } {
	# Procedure called to update C_SLOT_KERNEL_ID_103 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_103 { PARAM_VALUE.C_SLOT_KERNEL_ID_103 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_103
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_104 { PARAM_VALUE.C_SLOT_KERNEL_ID_104 } {
	# Procedure called to update C_SLOT_KERNEL_ID_104 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_104 { PARAM_VALUE.C_SLOT_KERNEL_ID_104 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_104
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_105 { PARAM_VALUE.C_SLOT_KERNEL_ID_105 } {
	# Procedure called to update C_SLOT_KERNEL_ID_105 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_105 { PARAM_VALUE.C_SLOT_KERNEL_ID_105 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_105
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_106 { PARAM_VALUE.C_SLOT_KERNEL_ID_106 } {
	# Procedure called to update C_SLOT_KERNEL_ID_106 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_106 { PARAM_VALUE.C_SLOT_KERNEL_ID_106 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_106
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_107 { PARAM_VALUE.C_SLOT_KERNEL_ID_107 } {
	# Procedure called to update C_SLOT_KERNEL_ID_107 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_107 { PARAM_VALUE.C_SLOT_KERNEL_ID_107 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_107
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_108 { PARAM_VALUE.C_SLOT_KERNEL_ID_108 } {
	# Procedure called to update C_SLOT_KERNEL_ID_108 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_108 { PARAM_VALUE.C_SLOT_KERNEL_ID_108 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_108
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_109 { PARAM_VALUE.C_SLOT_KERNEL_ID_109 } {
	# Procedure called to update C_SLOT_KERNEL_ID_109 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_109 { PARAM_VALUE.C_SLOT_KERNEL_ID_109 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_109
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_11 { PARAM_VALUE.C_SLOT_KERNEL_ID_11 } {
	# Procedure called to update C_SLOT_KERNEL_ID_11 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_11 { PARAM_VALUE.C_SLOT_KERNEL_ID_11 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_11
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_110 { PARAM_VALUE.C_SLOT_KERNEL_ID_110 } {
	# Procedure called to update C_SLOT_KERNEL_ID_110 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_110 { PARAM_VALUE.C_SLOT_KERNEL_ID_110 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_110
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_111 { PARAM_VALUE.C_SLOT_KERNEL_ID_111 } {
	# Procedure called to update C_SLOT_KERNEL_ID_111 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_111 { PARAM_VALUE.C_SLOT_KERNEL_ID_111 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_111
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_112 { PARAM_VALUE.C_SLOT_KERNEL_ID_112 } {
	# Procedure called to update C_SLOT_KERNEL_ID_112 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_112 { PARAM_VALUE.C_SLOT_KERNEL_ID_112 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_112
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_113 { PARAM_VALUE.C_SLOT_KERNEL_ID_113 } {
	# Procedure called to update C_SLOT_KERNEL_ID_113 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_113 { PARAM_VALUE.C_SLOT_KERNEL_ID_113 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_113
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_114 { PARAM_VALUE.C_SLOT_KERNEL_ID_114 } {
	# Procedure called to update C_SLOT_KERNEL_ID_114 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_114 { PARAM_VALUE.C_SLOT_KERNEL_ID_114 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_114
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_115 { PARAM_VALUE.C_SLOT_KERNEL_ID_115 } {
	# Procedure called to update C_SLOT_KERNEL_ID_115 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_115 { PARAM_VALUE.C_SLOT_KERNEL_ID_115 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_115
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_116 { PARAM_VALUE.C_SLOT_KERNEL_ID_116 } {
	# Procedure called to update C_SLOT_KERNEL_ID_116 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_116 { PARAM_VALUE.C_SLOT_KERNEL_ID_116 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_116
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_117 { PARAM_VALUE.C_SLOT_KERNEL_ID_117 } {
	# Procedure called to update C_SLOT_KERNEL_ID_117 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_117 { PARAM_VALUE.C_SLOT_KERNEL_ID_117 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_117
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_118 { PARAM_VALUE.C_SLOT_KERNEL_ID_118 } {
	# Procedure called to update C_SLOT_KERNEL_ID_118 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_118 { PARAM_VALUE.C_SLOT_KERNEL_ID_118 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_118
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_119 { PARAM_VALUE.C_SLOT_KERNEL_ID_119 } {
	# Procedure called to update C_SLOT_KERNEL_ID_119 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_119 { PARAM_VALUE.C_SLOT_KERNEL_ID_119 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_119
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_12 { PARAM_VALUE.C_SLOT_KERNEL_ID_12 } {
	# Procedure called to update C_SLOT_KERNEL_ID_12 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_12 { PARAM_VALUE.C_SLOT_KERNEL_ID_12 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_12
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_120 { PARAM_VALUE.C_SLOT_KERNEL_ID_120 } {
	# Procedure called to update C_SLOT_KERNEL_ID_120 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_120 { PARAM_VALUE.C_SLOT_KERNEL_ID_120 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_120
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_121 { PARAM_VALUE.C_SLOT_KERNEL_ID_121 } {
	# Procedure called to update C_SLOT_KERNEL_ID_121 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_121 { PARAM_VALUE.C_SLOT_KERNEL_ID_121 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_121
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_122 { PARAM_VALUE.C_SLOT_KERNEL_ID_122 } {
	# Procedure called to update C_SLOT_KERNEL_ID_122 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_122 { PARAM_VALUE.C_SLOT_KERNEL_ID_122 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_122
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_123 { PARAM_VALUE.C_SLOT_KERNEL_ID_123 } {
	# Procedure called to update C_SLOT_KERNEL_ID_123 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_123 { PARAM_VALUE.C_SLOT_KERNEL_ID_123 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_123
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_124 { PARAM_VALUE.C_SLOT_KERNEL_ID_124 } {
	# Procedure called to update C_SLOT_KERNEL_ID_124 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_124 { PARAM_VALUE.C_SLOT_KERNEL_ID_124 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_124
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_125 { PARAM_VALUE.C_SLOT_KERNEL_ID_125 } {
	# Procedure called to update C_SLOT_KERNEL_ID_125 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_125 { PARAM_VALUE.C_SLOT_KERNEL_ID_125 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_125
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_126 { PARAM_VALUE.C_SLOT_KERNEL_ID_126 } {
	# Procedure called to update C_SLOT_KERNEL_ID_126 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_126 { PARAM_VALUE.C_SLOT_KERNEL_ID_126 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_126
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_127 { PARAM_VALUE.C_SLOT_KERNEL_ID_127 } {
	# Procedure called to update C_SLOT_KERNEL_ID_127 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_127 { PARAM_VALUE.C_SLOT_KERNEL_ID_127 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_127
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_128 { PARAM_VALUE.C_SLOT_KERNEL_ID_128 } {
	# Procedure called to update C_SLOT_KERNEL_ID_128 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_128 { PARAM_VALUE.C_SLOT_KERNEL_ID_128 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_128
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_13 { PARAM_VALUE.C_SLOT_KERNEL_ID_13 } {
	# Procedure called to update C_SLOT_KERNEL_ID_13 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_13 { PARAM_VALUE.C_SLOT_KERNEL_ID_13 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_13
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_14 { PARAM_VALUE.C_SLOT_KERNEL_ID_14 } {
	# Procedure called to update C_SLOT_KERNEL_ID_14 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_14 { PARAM_VALUE.C_SLOT_KERNEL_ID_14 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_14
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_15 { PARAM_VALUE.C_SLOT_KERNEL_ID_15 } {
	# Procedure called to update C_SLOT_KERNEL_ID_15 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_15 { PARAM_VALUE.C_SLOT_KERNEL_ID_15 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_15
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_16 { PARAM_VALUE.C_SLOT_KERNEL_ID_16 } {
	# Procedure called to update C_SLOT_KERNEL_ID_16 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_16 { PARAM_VALUE.C_SLOT_KERNEL_ID_16 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_16
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_17 { PARAM_VALUE.C_SLOT_KERNEL_ID_17 } {
	# Procedure called to update C_SLOT_KERNEL_ID_17 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_17 { PARAM_VALUE.C_SLOT_KERNEL_ID_17 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_17
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_18 { PARAM_VALUE.C_SLOT_KERNEL_ID_18 } {
	# Procedure called to update C_SLOT_KERNEL_ID_18 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_18 { PARAM_VALUE.C_SLOT_KERNEL_ID_18 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_18
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_19 { PARAM_VALUE.C_SLOT_KERNEL_ID_19 } {
	# Procedure called to update C_SLOT_KERNEL_ID_19 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_19 { PARAM_VALUE.C_SLOT_KERNEL_ID_19 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_19
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_2 { PARAM_VALUE.C_SLOT_KERNEL_ID_2 } {
	# Procedure called to update C_SLOT_KERNEL_ID_2 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_2 { PARAM_VALUE.C_SLOT_KERNEL_ID_2 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_2
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_20 { PARAM_VALUE.C_SLOT_KERNEL_ID_20 } {
	# Procedure called to update C_SLOT_KERNEL_ID_20 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_20 { PARAM_VALUE.C_SLOT_KERNEL_ID_20 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_20
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_21 { PARAM_VALUE.C_SLOT_KERNEL_ID_21 } {
	# Procedure called to update C_SLOT_KERNEL_ID_21 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_21 { PARAM_VALUE.C_SLOT_KERNEL_ID_21 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_21
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_22 { PARAM_VALUE.C_SLOT_KERNEL_ID_22 } {
	# Procedure called to update C_SLOT_KERNEL_ID_22 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_22 { PARAM_VALUE.C_SLOT_KERNEL_ID_22 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_22
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_23 { PARAM_VALUE.C_SLOT_KERNEL_ID_23 } {
	# Procedure called to update C_SLOT_KERNEL_ID_23 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_23 { PARAM_VALUE.C_SLOT_KERNEL_ID_23 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_23
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_24 { PARAM_VALUE.C_SLOT_KERNEL_ID_24 } {
	# Procedure called to update C_SLOT_KERNEL_ID_24 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_24 { PARAM_VALUE.C_SLOT_KERNEL_ID_24 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_24
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_25 { PARAM_VALUE.C_SLOT_KERNEL_ID_25 } {
	# Procedure called to update C_SLOT_KERNEL_ID_25 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_25 { PARAM_VALUE.C_SLOT_KERNEL_ID_25 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_25
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_26 { PARAM_VALUE.C_SLOT_KERNEL_ID_26 } {
	# Procedure called to update C_SLOT_KERNEL_ID_26 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_26 { PARAM_VALUE.C_SLOT_KERNEL_ID_26 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_26
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_27 { PARAM_VALUE.C_SLOT_KERNEL_ID_27 } {
	# Procedure called to update C_SLOT_KERNEL_ID_27 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_27 { PARAM_VALUE.C_SLOT_KERNEL_ID_27 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_27
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_28 { PARAM_VALUE.C_SLOT_KERNEL_ID_28 } {
	# Procedure called to update C_SLOT_KERNEL_ID_28 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_28 { PARAM_VALUE.C_SLOT_KERNEL_ID_28 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_28
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_29 { PARAM_VALUE.C_SLOT_KERNEL_ID_29 } {
	# Procedure called to update C_SLOT_KERNEL_ID_29 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_29 { PARAM_VALUE.C_SLOT_KERNEL_ID_29 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_29
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_3 { PARAM_VALUE.C_SLOT_KERNEL_ID_3 } {
	# Procedure called to update C_SLOT_KERNEL_ID_3 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_3 { PARAM_VALUE.C_SLOT_KERNEL_ID_3 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_3
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_30 { PARAM_VALUE.C_SLOT_KERNEL_ID_30 } {
	# Procedure called to update C_SLOT_KERNEL_ID_30 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_30 { PARAM_VALUE.C_SLOT_KERNEL_ID_30 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_30
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_31 { PARAM_VALUE.C_SLOT_KERNEL_ID_31 } {
	# Procedure called to update C_SLOT_KERNEL_ID_31 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_31 { PARAM_VALUE.C_SLOT_KERNEL_ID_31 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_31
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_32 { PARAM_VALUE.C_SLOT_KERNEL_ID_32 } {
	# Procedure called to update C_SLOT_KERNEL_ID_32 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_32 { PARAM_VALUE.C_SLOT_KERNEL_ID_32 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_32
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_33 { PARAM_VALUE.C_SLOT_KERNEL_ID_33 } {
	# Procedure called to update C_SLOT_KERNEL_ID_33 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_33 { PARAM_VALUE.C_SLOT_KERNEL_ID_33 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_33
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_34 { PARAM_VALUE.C_SLOT_KERNEL_ID_34 } {
	# Procedure called to update C_SLOT_KERNEL_ID_34 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_34 { PARAM_VALUE.C_SLOT_KERNEL_ID_34 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_34
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_35 { PARAM_VALUE.C_SLOT_KERNEL_ID_35 } {
	# Procedure called to update C_SLOT_KERNEL_ID_35 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_35 { PARAM_VALUE.C_SLOT_KERNEL_ID_35 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_35
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_36 { PARAM_VALUE.C_SLOT_KERNEL_ID_36 } {
	# Procedure called to update C_SLOT_KERNEL_ID_36 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_36 { PARAM_VALUE.C_SLOT_KERNEL_ID_36 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_36
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_37 { PARAM_VALUE.C_SLOT_KERNEL_ID_37 } {
	# Procedure called to update C_SLOT_KERNEL_ID_37 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_37 { PARAM_VALUE.C_SLOT_KERNEL_ID_37 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_37
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_38 { PARAM_VALUE.C_SLOT_KERNEL_ID_38 } {
	# Procedure called to update C_SLOT_KERNEL_ID_38 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_38 { PARAM_VALUE.C_SLOT_KERNEL_ID_38 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_38
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_39 { PARAM_VALUE.C_SLOT_KERNEL_ID_39 } {
	# Procedure called to update C_SLOT_KERNEL_ID_39 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_39 { PARAM_VALUE.C_SLOT_KERNEL_ID_39 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_39
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_4 { PARAM_VALUE.C_SLOT_KERNEL_ID_4 } {
	# Procedure called to update C_SLOT_KERNEL_ID_4 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_4 { PARAM_VALUE.C_SLOT_KERNEL_ID_4 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_4
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_40 { PARAM_VALUE.C_SLOT_KERNEL_ID_40 } {
	# Procedure called to update C_SLOT_KERNEL_ID_40 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_40 { PARAM_VALUE.C_SLOT_KERNEL_ID_40 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_40
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_41 { PARAM_VALUE.C_SLOT_KERNEL_ID_41 } {
	# Procedure called to update C_SLOT_KERNEL_ID_41 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_41 { PARAM_VALUE.C_SLOT_KERNEL_ID_41 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_41
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_42 { PARAM_VALUE.C_SLOT_KERNEL_ID_42 } {
	# Procedure called to update C_SLOT_KERNEL_ID_42 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_42 { PARAM_VALUE.C_SLOT_KERNEL_ID_42 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_42
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_43 { PARAM_VALUE.C_SLOT_KERNEL_ID_43 } {
	# Procedure called to update C_SLOT_KERNEL_ID_43 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_43 { PARAM_VALUE.C_SLOT_KERNEL_ID_43 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_43
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_44 { PARAM_VALUE.C_SLOT_KERNEL_ID_44 } {
	# Procedure called to update C_SLOT_KERNEL_ID_44 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_44 { PARAM_VALUE.C_SLOT_KERNEL_ID_44 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_44
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_45 { PARAM_VALUE.C_SLOT_KERNEL_ID_45 } {
	# Procedure called to update C_SLOT_KERNEL_ID_45 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_45 { PARAM_VALUE.C_SLOT_KERNEL_ID_45 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_45
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_46 { PARAM_VALUE.C_SLOT_KERNEL_ID_46 } {
	# Procedure called to update C_SLOT_KERNEL_ID_46 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_46 { PARAM_VALUE.C_SLOT_KERNEL_ID_46 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_46
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_47 { PARAM_VALUE.C_SLOT_KERNEL_ID_47 } {
	# Procedure called to update C_SLOT_KERNEL_ID_47 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_47 { PARAM_VALUE.C_SLOT_KERNEL_ID_47 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_47
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_48 { PARAM_VALUE.C_SLOT_KERNEL_ID_48 } {
	# Procedure called to update C_SLOT_KERNEL_ID_48 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_48 { PARAM_VALUE.C_SLOT_KERNEL_ID_48 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_48
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_49 { PARAM_VALUE.C_SLOT_KERNEL_ID_49 } {
	# Procedure called to update C_SLOT_KERNEL_ID_49 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_49 { PARAM_VALUE.C_SLOT_KERNEL_ID_49 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_49
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_5 { PARAM_VALUE.C_SLOT_KERNEL_ID_5 } {
	# Procedure called to update C_SLOT_KERNEL_ID_5 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_5 { PARAM_VALUE.C_SLOT_KERNEL_ID_5 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_5
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_50 { PARAM_VALUE.C_SLOT_KERNEL_ID_50 } {
	# Procedure called to update C_SLOT_KERNEL_ID_50 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_50 { PARAM_VALUE.C_SLOT_KERNEL_ID_50 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_50
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_51 { PARAM_VALUE.C_SLOT_KERNEL_ID_51 } {
	# Procedure called to update C_SLOT_KERNEL_ID_51 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_51 { PARAM_VALUE.C_SLOT_KERNEL_ID_51 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_51
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_52 { PARAM_VALUE.C_SLOT_KERNEL_ID_52 } {
	# Procedure called to update C_SLOT_KERNEL_ID_52 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_52 { PARAM_VALUE.C_SLOT_KERNEL_ID_52 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_52
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_53 { PARAM_VALUE.C_SLOT_KERNEL_ID_53 } {
	# Procedure called to update C_SLOT_KERNEL_ID_53 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_53 { PARAM_VALUE.C_SLOT_KERNEL_ID_53 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_53
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_54 { PARAM_VALUE.C_SLOT_KERNEL_ID_54 } {
	# Procedure called to update C_SLOT_KERNEL_ID_54 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_54 { PARAM_VALUE.C_SLOT_KERNEL_ID_54 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_54
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_55 { PARAM_VALUE.C_SLOT_KERNEL_ID_55 } {
	# Procedure called to update C_SLOT_KERNEL_ID_55 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_55 { PARAM_VALUE.C_SLOT_KERNEL_ID_55 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_55
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_56 { PARAM_VALUE.C_SLOT_KERNEL_ID_56 } {
	# Procedure called to update C_SLOT_KERNEL_ID_56 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_56 { PARAM_VALUE.C_SLOT_KERNEL_ID_56 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_56
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_57 { PARAM_VALUE.C_SLOT_KERNEL_ID_57 } {
	# Procedure called to update C_SLOT_KERNEL_ID_57 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_57 { PARAM_VALUE.C_SLOT_KERNEL_ID_57 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_57
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_58 { PARAM_VALUE.C_SLOT_KERNEL_ID_58 } {
	# Procedure called to update C_SLOT_KERNEL_ID_58 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_58 { PARAM_VALUE.C_SLOT_KERNEL_ID_58 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_58
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_59 { PARAM_VALUE.C_SLOT_KERNEL_ID_59 } {
	# Procedure called to update C_SLOT_KERNEL_ID_59 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_59 { PARAM_VALUE.C_SLOT_KERNEL_ID_59 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_59
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_6 { PARAM_VALUE.C_SLOT_KERNEL_ID_6 } {
	# Procedure called to update C_SLOT_KERNEL_ID_6 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_6 { PARAM_VALUE.C_SLOT_KERNEL_ID_6 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_6
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_60 { PARAM_VALUE.C_SLOT_KERNEL_ID_60 } {
	# Procedure called to update C_SLOT_KERNEL_ID_60 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_60 { PARAM_VALUE.C_SLOT_KERNEL_ID_60 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_60
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_61 { PARAM_VALUE.C_SLOT_KERNEL_ID_61 } {
	# Procedure called to update C_SLOT_KERNEL_ID_61 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_61 { PARAM_VALUE.C_SLOT_KERNEL_ID_61 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_61
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_62 { PARAM_VALUE.C_SLOT_KERNEL_ID_62 } {
	# Procedure called to update C_SLOT_KERNEL_ID_62 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_62 { PARAM_VALUE.C_SLOT_KERNEL_ID_62 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_62
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_63 { PARAM_VALUE.C_SLOT_KERNEL_ID_63 } {
	# Procedure called to update C_SLOT_KERNEL_ID_63 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_63 { PARAM_VALUE.C_SLOT_KERNEL_ID_63 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_63
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_64 { PARAM_VALUE.C_SLOT_KERNEL_ID_64 } {
	# Procedure called to update C_SLOT_KERNEL_ID_64 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_64 { PARAM_VALUE.C_SLOT_KERNEL_ID_64 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_64
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_65 { PARAM_VALUE.C_SLOT_KERNEL_ID_65 } {
	# Procedure called to update C_SLOT_KERNEL_ID_65 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_65 { PARAM_VALUE.C_SLOT_KERNEL_ID_65 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_65
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_66 { PARAM_VALUE.C_SLOT_KERNEL_ID_66 } {
	# Procedure called to update C_SLOT_KERNEL_ID_66 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_66 { PARAM_VALUE.C_SLOT_KERNEL_ID_66 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_66
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_67 { PARAM_VALUE.C_SLOT_KERNEL_ID_67 } {
	# Procedure called to update C_SLOT_KERNEL_ID_67 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_67 { PARAM_VALUE.C_SLOT_KERNEL_ID_67 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_67
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_68 { PARAM_VALUE.C_SLOT_KERNEL_ID_68 } {
	# Procedure called to update C_SLOT_KERNEL_ID_68 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_68 { PARAM_VALUE.C_SLOT_KERNEL_ID_68 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_68
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_69 { PARAM_VALUE.C_SLOT_KERNEL_ID_69 } {
	# Procedure called to update C_SLOT_KERNEL_ID_69 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_69 { PARAM_VALUE.C_SLOT_KERNEL_ID_69 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_69
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_7 { PARAM_VALUE.C_SLOT_KERNEL_ID_7 } {
	# Procedure called to update C_SLOT_KERNEL_ID_7 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_7 { PARAM_VALUE.C_SLOT_KERNEL_ID_7 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_7
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_70 { PARAM_VALUE.C_SLOT_KERNEL_ID_70 } {
	# Procedure called to update C_SLOT_KERNEL_ID_70 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_70 { PARAM_VALUE.C_SLOT_KERNEL_ID_70 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_70
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_71 { PARAM_VALUE.C_SLOT_KERNEL_ID_71 } {
	# Procedure called to update C_SLOT_KERNEL_ID_71 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_71 { PARAM_VALUE.C_SLOT_KERNEL_ID_71 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_71
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_72 { PARAM_VALUE.C_SLOT_KERNEL_ID_72 } {
	# Procedure called to update C_SLOT_KERNEL_ID_72 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_72 { PARAM_VALUE.C_SLOT_KERNEL_ID_72 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_72
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_73 { PARAM_VALUE.C_SLOT_KERNEL_ID_73 } {
	# Procedure called to update C_SLOT_KERNEL_ID_73 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_73 { PARAM_VALUE.C_SLOT_KERNEL_ID_73 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_73
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_74 { PARAM_VALUE.C_SLOT_KERNEL_ID_74 } {
	# Procedure called to update C_SLOT_KERNEL_ID_74 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_74 { PARAM_VALUE.C_SLOT_KERNEL_ID_74 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_74
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_75 { PARAM_VALUE.C_SLOT_KERNEL_ID_75 } {
	# Procedure called to update C_SLOT_KERNEL_ID_75 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_75 { PARAM_VALUE.C_SLOT_KERNEL_ID_75 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_75
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_76 { PARAM_VALUE.C_SLOT_KERNEL_ID_76 } {
	# Procedure called to update C_SLOT_KERNEL_ID_76 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_76 { PARAM_VALUE.C_SLOT_KERNEL_ID_76 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_76
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_77 { PARAM_VALUE.C_SLOT_KERNEL_ID_77 } {
	# Procedure called to update C_SLOT_KERNEL_ID_77 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_77 { PARAM_VALUE.C_SLOT_KERNEL_ID_77 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_77
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_78 { PARAM_VALUE.C_SLOT_KERNEL_ID_78 } {
	# Procedure called to update C_SLOT_KERNEL_ID_78 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_78 { PARAM_VALUE.C_SLOT_KERNEL_ID_78 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_78
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_79 { PARAM_VALUE.C_SLOT_KERNEL_ID_79 } {
	# Procedure called to update C_SLOT_KERNEL_ID_79 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_79 { PARAM_VALUE.C_SLOT_KERNEL_ID_79 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_79
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_8 { PARAM_VALUE.C_SLOT_KERNEL_ID_8 } {
	# Procedure called to update C_SLOT_KERNEL_ID_8 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_8 { PARAM_VALUE.C_SLOT_KERNEL_ID_8 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_8
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_80 { PARAM_VALUE.C_SLOT_KERNEL_ID_80 } {
	# Procedure called to update C_SLOT_KERNEL_ID_80 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_80 { PARAM_VALUE.C_SLOT_KERNEL_ID_80 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_80
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_81 { PARAM_VALUE.C_SLOT_KERNEL_ID_81 } {
	# Procedure called to update C_SLOT_KERNEL_ID_81 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_81 { PARAM_VALUE.C_SLOT_KERNEL_ID_81 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_81
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_82 { PARAM_VALUE.C_SLOT_KERNEL_ID_82 } {
	# Procedure called to update C_SLOT_KERNEL_ID_82 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_82 { PARAM_VALUE.C_SLOT_KERNEL_ID_82 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_82
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_83 { PARAM_VALUE.C_SLOT_KERNEL_ID_83 } {
	# Procedure called to update C_SLOT_KERNEL_ID_83 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_83 { PARAM_VALUE.C_SLOT_KERNEL_ID_83 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_83
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_84 { PARAM_VALUE.C_SLOT_KERNEL_ID_84 } {
	# Procedure called to update C_SLOT_KERNEL_ID_84 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_84 { PARAM_VALUE.C_SLOT_KERNEL_ID_84 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_84
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_85 { PARAM_VALUE.C_SLOT_KERNEL_ID_85 } {
	# Procedure called to update C_SLOT_KERNEL_ID_85 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_85 { PARAM_VALUE.C_SLOT_KERNEL_ID_85 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_85
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_86 { PARAM_VALUE.C_SLOT_KERNEL_ID_86 } {
	# Procedure called to update C_SLOT_KERNEL_ID_86 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_86 { PARAM_VALUE.C_SLOT_KERNEL_ID_86 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_86
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_87 { PARAM_VALUE.C_SLOT_KERNEL_ID_87 } {
	# Procedure called to update C_SLOT_KERNEL_ID_87 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_87 { PARAM_VALUE.C_SLOT_KERNEL_ID_87 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_87
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_88 { PARAM_VALUE.C_SLOT_KERNEL_ID_88 } {
	# Procedure called to update C_SLOT_KERNEL_ID_88 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_88 { PARAM_VALUE.C_SLOT_KERNEL_ID_88 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_88
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_89 { PARAM_VALUE.C_SLOT_KERNEL_ID_89 } {
	# Procedure called to update C_SLOT_KERNEL_ID_89 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_89 { PARAM_VALUE.C_SLOT_KERNEL_ID_89 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_89
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_9 { PARAM_VALUE.C_SLOT_KERNEL_ID_9 } {
	# Procedure called to update C_SLOT_KERNEL_ID_9 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_9 { PARAM_VALUE.C_SLOT_KERNEL_ID_9 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_9
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_90 { PARAM_VALUE.C_SLOT_KERNEL_ID_90 } {
	# Procedure called to update C_SLOT_KERNEL_ID_90 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_90 { PARAM_VALUE.C_SLOT_KERNEL_ID_90 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_90
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_91 { PARAM_VALUE.C_SLOT_KERNEL_ID_91 } {
	# Procedure called to update C_SLOT_KERNEL_ID_91 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_91 { PARAM_VALUE.C_SLOT_KERNEL_ID_91 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_91
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_92 { PARAM_VALUE.C_SLOT_KERNEL_ID_92 } {
	# Procedure called to update C_SLOT_KERNEL_ID_92 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_92 { PARAM_VALUE.C_SLOT_KERNEL_ID_92 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_92
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_93 { PARAM_VALUE.C_SLOT_KERNEL_ID_93 } {
	# Procedure called to update C_SLOT_KERNEL_ID_93 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_93 { PARAM_VALUE.C_SLOT_KERNEL_ID_93 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_93
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_94 { PARAM_VALUE.C_SLOT_KERNEL_ID_94 } {
	# Procedure called to update C_SLOT_KERNEL_ID_94 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_94 { PARAM_VALUE.C_SLOT_KERNEL_ID_94 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_94
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_95 { PARAM_VALUE.C_SLOT_KERNEL_ID_95 } {
	# Procedure called to update C_SLOT_KERNEL_ID_95 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_95 { PARAM_VALUE.C_SLOT_KERNEL_ID_95 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_95
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_96 { PARAM_VALUE.C_SLOT_KERNEL_ID_96 } {
	# Procedure called to update C_SLOT_KERNEL_ID_96 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_96 { PARAM_VALUE.C_SLOT_KERNEL_ID_96 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_96
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_97 { PARAM_VALUE.C_SLOT_KERNEL_ID_97 } {
	# Procedure called to update C_SLOT_KERNEL_ID_97 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_97 { PARAM_VALUE.C_SLOT_KERNEL_ID_97 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_97
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_98 { PARAM_VALUE.C_SLOT_KERNEL_ID_98 } {
	# Procedure called to update C_SLOT_KERNEL_ID_98 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_98 { PARAM_VALUE.C_SLOT_KERNEL_ID_98 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_98
	return true
}

proc update_PARAM_VALUE.C_SLOT_KERNEL_ID_99 { PARAM_VALUE.C_SLOT_KERNEL_ID_99 } {
	# Procedure called to update C_SLOT_KERNEL_ID_99 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SLOT_KERNEL_ID_99 { PARAM_VALUE.C_SLOT_KERNEL_ID_99 } {
	# Procedure called to validate C_SLOT_KERNEL_ID_99
	return true
}


proc update_MODELPARAM_VALUE.C_INTC_COUNT { MODELPARAM_VALUE.C_INTC_COUNT PARAM_VALUE.C_INTC_COUNT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_INTC_COUNT}] ${MODELPARAM_VALUE.C_INTC_COUNT}
}

proc update_MODELPARAM_VALUE.C_CAPABILITIES_0 { MODELPARAM_VALUE.C_CAPABILITIES_0 PARAM_VALUE.C_CAPABILITIES_0 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_CAPABILITIES_0}] ${MODELPARAM_VALUE.C_CAPABILITIES_0}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_1 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_1 PARAM_VALUE.C_SLOT_KERNEL_ID_1 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_1}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_1}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_2 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_2 PARAM_VALUE.C_SLOT_KERNEL_ID_2 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_2}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_2}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_3 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_3 PARAM_VALUE.C_SLOT_KERNEL_ID_3 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_3}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_3}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_4 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_4 PARAM_VALUE.C_SLOT_KERNEL_ID_4 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_4}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_4}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_5 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_5 PARAM_VALUE.C_SLOT_KERNEL_ID_5 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_5}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_5}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_6 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_6 PARAM_VALUE.C_SLOT_KERNEL_ID_6 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_6}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_6}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_7 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_7 PARAM_VALUE.C_SLOT_KERNEL_ID_7 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_7}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_7}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_8 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_8 PARAM_VALUE.C_SLOT_KERNEL_ID_8 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_8}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_8}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_9 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_9 PARAM_VALUE.C_SLOT_KERNEL_ID_9 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_9}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_9}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_10 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_10 PARAM_VALUE.C_SLOT_KERNEL_ID_10 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_10}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_10}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_11 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_11 PARAM_VALUE.C_SLOT_KERNEL_ID_11 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_11}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_11}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_12 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_12 PARAM_VALUE.C_SLOT_KERNEL_ID_12 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_12}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_12}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_13 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_13 PARAM_VALUE.C_SLOT_KERNEL_ID_13 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_13}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_13}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_14 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_14 PARAM_VALUE.C_SLOT_KERNEL_ID_14 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_14}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_14}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_15 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_15 PARAM_VALUE.C_SLOT_KERNEL_ID_15 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_15}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_15}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_16 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_16 PARAM_VALUE.C_SLOT_KERNEL_ID_16 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_16}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_16}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_17 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_17 PARAM_VALUE.C_SLOT_KERNEL_ID_17 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_17}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_17}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_18 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_18 PARAM_VALUE.C_SLOT_KERNEL_ID_18 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_18}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_18}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_19 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_19 PARAM_VALUE.C_SLOT_KERNEL_ID_19 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_19}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_19}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_20 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_20 PARAM_VALUE.C_SLOT_KERNEL_ID_20 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_20}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_20}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_21 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_21 PARAM_VALUE.C_SLOT_KERNEL_ID_21 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_21}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_21}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_22 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_22 PARAM_VALUE.C_SLOT_KERNEL_ID_22 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_22}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_22}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_23 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_23 PARAM_VALUE.C_SLOT_KERNEL_ID_23 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_23}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_23}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_24 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_24 PARAM_VALUE.C_SLOT_KERNEL_ID_24 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_24}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_24}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_25 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_25 PARAM_VALUE.C_SLOT_KERNEL_ID_25 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_25}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_25}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_26 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_26 PARAM_VALUE.C_SLOT_KERNEL_ID_26 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_26}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_26}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_27 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_27 PARAM_VALUE.C_SLOT_KERNEL_ID_27 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_27}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_27}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_28 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_28 PARAM_VALUE.C_SLOT_KERNEL_ID_28 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_28}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_28}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_29 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_29 PARAM_VALUE.C_SLOT_KERNEL_ID_29 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_29}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_29}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_30 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_30 PARAM_VALUE.C_SLOT_KERNEL_ID_30 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_30}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_30}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_31 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_31 PARAM_VALUE.C_SLOT_KERNEL_ID_31 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_31}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_31}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_32 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_32 PARAM_VALUE.C_SLOT_KERNEL_ID_32 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_32}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_32}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_33 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_33 PARAM_VALUE.C_SLOT_KERNEL_ID_33 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_33}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_33}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_34 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_34 PARAM_VALUE.C_SLOT_KERNEL_ID_34 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_34}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_34}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_35 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_35 PARAM_VALUE.C_SLOT_KERNEL_ID_35 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_35}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_35}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_36 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_36 PARAM_VALUE.C_SLOT_KERNEL_ID_36 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_36}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_36}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_37 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_37 PARAM_VALUE.C_SLOT_KERNEL_ID_37 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_37}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_37}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_38 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_38 PARAM_VALUE.C_SLOT_KERNEL_ID_38 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_38}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_38}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_39 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_39 PARAM_VALUE.C_SLOT_KERNEL_ID_39 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_39}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_39}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_40 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_40 PARAM_VALUE.C_SLOT_KERNEL_ID_40 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_40}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_40}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_41 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_41 PARAM_VALUE.C_SLOT_KERNEL_ID_41 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_41}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_41}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_42 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_42 PARAM_VALUE.C_SLOT_KERNEL_ID_42 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_42}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_42}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_43 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_43 PARAM_VALUE.C_SLOT_KERNEL_ID_43 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_43}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_43}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_44 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_44 PARAM_VALUE.C_SLOT_KERNEL_ID_44 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_44}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_44}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_45 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_45 PARAM_VALUE.C_SLOT_KERNEL_ID_45 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_45}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_45}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_46 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_46 PARAM_VALUE.C_SLOT_KERNEL_ID_46 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_46}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_46}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_47 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_47 PARAM_VALUE.C_SLOT_KERNEL_ID_47 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_47}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_47}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_48 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_48 PARAM_VALUE.C_SLOT_KERNEL_ID_48 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_48}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_48}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_49 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_49 PARAM_VALUE.C_SLOT_KERNEL_ID_49 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_49}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_49}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_50 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_50 PARAM_VALUE.C_SLOT_KERNEL_ID_50 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_50}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_50}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_51 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_51 PARAM_VALUE.C_SLOT_KERNEL_ID_51 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_51}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_51}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_52 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_52 PARAM_VALUE.C_SLOT_KERNEL_ID_52 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_52}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_52}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_53 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_53 PARAM_VALUE.C_SLOT_KERNEL_ID_53 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_53}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_53}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_54 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_54 PARAM_VALUE.C_SLOT_KERNEL_ID_54 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_54}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_54}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_55 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_55 PARAM_VALUE.C_SLOT_KERNEL_ID_55 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_55}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_55}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_56 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_56 PARAM_VALUE.C_SLOT_KERNEL_ID_56 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_56}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_56}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_57 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_57 PARAM_VALUE.C_SLOT_KERNEL_ID_57 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_57}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_57}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_58 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_58 PARAM_VALUE.C_SLOT_KERNEL_ID_58 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_58}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_58}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_59 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_59 PARAM_VALUE.C_SLOT_KERNEL_ID_59 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_59}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_59}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_60 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_60 PARAM_VALUE.C_SLOT_KERNEL_ID_60 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_60}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_60}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_61 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_61 PARAM_VALUE.C_SLOT_KERNEL_ID_61 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_61}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_61}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_62 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_62 PARAM_VALUE.C_SLOT_KERNEL_ID_62 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_62}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_62}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_63 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_63 PARAM_VALUE.C_SLOT_KERNEL_ID_63 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_63}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_63}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_64 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_64 PARAM_VALUE.C_SLOT_KERNEL_ID_64 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_64}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_64}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_65 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_65 PARAM_VALUE.C_SLOT_KERNEL_ID_65 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_65}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_65}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_66 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_66 PARAM_VALUE.C_SLOT_KERNEL_ID_66 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_66}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_66}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_67 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_67 PARAM_VALUE.C_SLOT_KERNEL_ID_67 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_67}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_67}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_68 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_68 PARAM_VALUE.C_SLOT_KERNEL_ID_68 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_68}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_68}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_69 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_69 PARAM_VALUE.C_SLOT_KERNEL_ID_69 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_69}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_69}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_70 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_70 PARAM_VALUE.C_SLOT_KERNEL_ID_70 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_70}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_70}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_71 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_71 PARAM_VALUE.C_SLOT_KERNEL_ID_71 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_71}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_71}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_72 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_72 PARAM_VALUE.C_SLOT_KERNEL_ID_72 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_72}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_72}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_73 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_73 PARAM_VALUE.C_SLOT_KERNEL_ID_73 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_73}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_73}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_74 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_74 PARAM_VALUE.C_SLOT_KERNEL_ID_74 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_74}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_74}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_75 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_75 PARAM_VALUE.C_SLOT_KERNEL_ID_75 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_75}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_75}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_76 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_76 PARAM_VALUE.C_SLOT_KERNEL_ID_76 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_76}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_76}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_77 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_77 PARAM_VALUE.C_SLOT_KERNEL_ID_77 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_77}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_77}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_78 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_78 PARAM_VALUE.C_SLOT_KERNEL_ID_78 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_78}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_78}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_79 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_79 PARAM_VALUE.C_SLOT_KERNEL_ID_79 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_79}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_79}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_80 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_80 PARAM_VALUE.C_SLOT_KERNEL_ID_80 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_80}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_80}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_81 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_81 PARAM_VALUE.C_SLOT_KERNEL_ID_81 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_81}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_81}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_82 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_82 PARAM_VALUE.C_SLOT_KERNEL_ID_82 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_82}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_82}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_83 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_83 PARAM_VALUE.C_SLOT_KERNEL_ID_83 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_83}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_83}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_84 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_84 PARAM_VALUE.C_SLOT_KERNEL_ID_84 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_84}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_84}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_85 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_85 PARAM_VALUE.C_SLOT_KERNEL_ID_85 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_85}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_85}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_86 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_86 PARAM_VALUE.C_SLOT_KERNEL_ID_86 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_86}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_86}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_87 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_87 PARAM_VALUE.C_SLOT_KERNEL_ID_87 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_87}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_87}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_88 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_88 PARAM_VALUE.C_SLOT_KERNEL_ID_88 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_88}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_88}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_89 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_89 PARAM_VALUE.C_SLOT_KERNEL_ID_89 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_89}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_89}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_90 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_90 PARAM_VALUE.C_SLOT_KERNEL_ID_90 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_90}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_90}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_91 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_91 PARAM_VALUE.C_SLOT_KERNEL_ID_91 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_91}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_91}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_92 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_92 PARAM_VALUE.C_SLOT_KERNEL_ID_92 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_92}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_92}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_93 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_93 PARAM_VALUE.C_SLOT_KERNEL_ID_93 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_93}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_93}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_94 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_94 PARAM_VALUE.C_SLOT_KERNEL_ID_94 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_94}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_94}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_95 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_95 PARAM_VALUE.C_SLOT_KERNEL_ID_95 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_95}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_95}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_96 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_96 PARAM_VALUE.C_SLOT_KERNEL_ID_96 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_96}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_96}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_97 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_97 PARAM_VALUE.C_SLOT_KERNEL_ID_97 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_97}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_97}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_98 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_98 PARAM_VALUE.C_SLOT_KERNEL_ID_98 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_98}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_98}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_99 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_99 PARAM_VALUE.C_SLOT_KERNEL_ID_99 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_99}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_99}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_100 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_100 PARAM_VALUE.C_SLOT_KERNEL_ID_100 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_100}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_100}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_101 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_101 PARAM_VALUE.C_SLOT_KERNEL_ID_101 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_101}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_101}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_102 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_102 PARAM_VALUE.C_SLOT_KERNEL_ID_102 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_102}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_102}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_103 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_103 PARAM_VALUE.C_SLOT_KERNEL_ID_103 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_103}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_103}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_104 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_104 PARAM_VALUE.C_SLOT_KERNEL_ID_104 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_104}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_104}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_105 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_105 PARAM_VALUE.C_SLOT_KERNEL_ID_105 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_105}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_105}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_106 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_106 PARAM_VALUE.C_SLOT_KERNEL_ID_106 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_106}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_106}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_107 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_107 PARAM_VALUE.C_SLOT_KERNEL_ID_107 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_107}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_107}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_108 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_108 PARAM_VALUE.C_SLOT_KERNEL_ID_108 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_108}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_108}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_109 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_109 PARAM_VALUE.C_SLOT_KERNEL_ID_109 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_109}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_109}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_110 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_110 PARAM_VALUE.C_SLOT_KERNEL_ID_110 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_110}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_110}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_111 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_111 PARAM_VALUE.C_SLOT_KERNEL_ID_111 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_111}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_111}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_112 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_112 PARAM_VALUE.C_SLOT_KERNEL_ID_112 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_112}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_112}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_113 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_113 PARAM_VALUE.C_SLOT_KERNEL_ID_113 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_113}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_113}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_114 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_114 PARAM_VALUE.C_SLOT_KERNEL_ID_114 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_114}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_114}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_115 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_115 PARAM_VALUE.C_SLOT_KERNEL_ID_115 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_115}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_115}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_116 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_116 PARAM_VALUE.C_SLOT_KERNEL_ID_116 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_116}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_116}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_117 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_117 PARAM_VALUE.C_SLOT_KERNEL_ID_117 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_117}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_117}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_118 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_118 PARAM_VALUE.C_SLOT_KERNEL_ID_118 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_118}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_118}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_119 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_119 PARAM_VALUE.C_SLOT_KERNEL_ID_119 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_119}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_119}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_120 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_120 PARAM_VALUE.C_SLOT_KERNEL_ID_120 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_120}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_120}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_121 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_121 PARAM_VALUE.C_SLOT_KERNEL_ID_121 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_121}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_121}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_122 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_122 PARAM_VALUE.C_SLOT_KERNEL_ID_122 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_122}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_122}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_123 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_123 PARAM_VALUE.C_SLOT_KERNEL_ID_123 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_123}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_123}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_124 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_124 PARAM_VALUE.C_SLOT_KERNEL_ID_124 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_124}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_124}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_125 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_125 PARAM_VALUE.C_SLOT_KERNEL_ID_125 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_125}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_125}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_126 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_126 PARAM_VALUE.C_SLOT_KERNEL_ID_126 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_126}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_126}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_127 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_127 PARAM_VALUE.C_SLOT_KERNEL_ID_127 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_127}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_127}
}

proc update_MODELPARAM_VALUE.C_SLOT_KERNEL_ID_128 { MODELPARAM_VALUE.C_SLOT_KERNEL_ID_128 PARAM_VALUE.C_SLOT_KERNEL_ID_128 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SLOT_KERNEL_ID_128}] ${MODELPARAM_VALUE.C_SLOT_KERNEL_ID_128}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH}
}

