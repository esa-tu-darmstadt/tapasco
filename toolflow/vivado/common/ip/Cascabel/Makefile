CXX_NO_OPT=1
PARALLEL_SIM_LINK=1

TOP_MODULE=mkPacketProcessor
TESTBENCH_MODULE=packetprocessor_tb
IGNORE_MODULES=mkTestbench mkTestsMainTest
MAIN_MODULE=PacketProcessor
TESTBENCH_FILE=src/packetprocessor_tb.bsv
C_FLAGS=

EXTRA_BSV_LIBS:=
EXTRA_LIBRARIES:=
RUN_FLAGS:=

ifeq ($(RUN_TEST),)
RUN_TEST=TestsMainTest
endif

ifndef EXTRA_FLAGS
EXTRA_FLAGS:=
endif

PROJECT_NAME=Cascabel

EXTRA_FLAGS+=-D "RUN_TEST=$(RUN_TEST)"
EXTRA_FLAGS+=-show-schedule

VIVADO_ADD_PARAMS += 'ipx::associate_bus_interfaces -busif M_AXI -clock CLK -remove [ipx::current_core]'
VIVADO_ADD_PARAMS += 'ipx::associate_bus_interfaces -busif M_AXI -clock CLK_design_clk [ipx::current_core]'
VIVADO_ADD_PARAMS += 'ipx::infer_bus_interface intr_host xilinx.com:signal:interrupt_rtl:1.0 [ipx::current_core]'
VIVADO_ADD_PARAMS += 'set_property VALUE EDGE_RISING [ipx::get_bus_parameters -of_objects [ipx::get_bus_interfaces intr_host -of_objects [ipx::current_core]] SENSITIVITY]'
VIVADO_ADD_PARAMS += 'ipx::add_bus_parameter PortWidth [ipx::get_bus_interfaces intr_host -of_objects [ipx::current_core]]'
VIVADO_ADD_PARAMS += 'set_property VALUE [expr [get_property SIZE_LEFT [ipx::get_ports intr_host]] + 1] [ipx::get_bus_parameters -of_objects [ipx::get_bus_interfaces intr_host -of_objects [ipx::current_core]] PortWidth]'

CONSTRAINT_FILES := "$(PWD)/constraints/cascabel.xdc,LATE"

include $(BSV_EXTRA)/BlueAXI/BlueAXI.mk

include $(BSV_EXTRA)/BlueLib/BlueLib.mk

BASE_DIR:=$(BSV_TOOLS)
include $(BSV_TOOLS)/scripts/rules.mk
