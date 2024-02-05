TOPLEVEL_LANG ?= verilog

SIM = questa
MODELSIM=$(PWD)/simulate_testbench.sim/sim_1/behav/questa/modelsim.ini

SIM_LIB  = $(PWD)/compile_simlib/questa

SCRIPT_FILE = $(PWD)/simulate_testbench.sim/sim_1/behav/questa/pe_compile.do; \
do $(PWD)/simulate_testbench.sim/sim_1/behav/questa/pe_elaborate.do; \
exec cp $(PWD)/simulate_testbench.sim/sim_1/behav/questa/system_tapasco_status_base_0.mif .;

SIM_IP := composition.zip
BOARD_PART := xczu3eg-sbva484-1-e
IP_DEFS := esa.informatik.tu-darmstadt.de:sim:*
SIM_PORT := 4040
export SIM_PORT
UNSAFE_SIM := 0
export UNSAFE_SIM

RUN_ARGS=-noautoldlibpath
GUI:=0

RTL_LIBRARY = xil_defaultlib
TOPLEVEL := pe
MODULE   := simulation
PYTHON_PATH := .
PYGPI_ENTRY_POINT := simulation:sim_entry

SHELL=/bin/bash

ifeq ("$(wildcard .venv)", "")
  CONFIGURE_NEEDED = 1
else
  SIM_ARGS=-lib xil_defaultlib pe_opt -suppress 7061 -suppress 12003 -onfinish exit -pli "$(shell cocotb-config --prefix)/cocotb/libs/libcocotbvpi_modelsim.so"; \#
  include $(shell cocotb-config --makefiles)/Makefile.sim
endif

ifeq ($(TAPASCO_HOME_RUNTIME),)
  $(error "Tapasco Home Runtime not found. Please source correct tapasco-setup.sh!")
endif

QUESTA_HOME := $(abspath $(dir $(shell which vsim))/../)
QUESTA_GCC_LIST := $(wildcard $(QUESTA_HOME)/gcc-1*)
ifeq ($(QUESTA_GCC_LIST),)
QUESTA_GCC_LIST := $(wildcard $(QUESTA_HOME)/gcc-*)
endif
QUESTA_GCC := $(lastword 1, $(sort ${QUESTA_GCC_LIST}))
ifeq ($(QUESTA_HOME),)
  $(error "Questa installation not detected. Please make sure questa simulator is installed an on PATH")
endif
ifeq ($(QUESTA_GCC),)
  $(error "Questa installation not detected. Please make sure questa simulator is installed an on PATH")
endif

configure:
	python -m venv .venv
	source .venv/bin/activate; \
	pip install -r requirements.txt

simlib_questa:
	echo "compile_simlib -simulator questa -simulator_exec_path {$(QUESTA_HOME)/bin} -gcc_exec_path {$(QUESTA_GCC)/bin} -family zynquplus -language all -library all -dir {compile_simlib/questa}" > questa.tcl
	vivado -nojournal -nolog -mode batch -source questa.tcl

protos: $(if $(CONFIGURE_NEEDED),configure)
ifeq ($(wildcard grpc_gen),)
	$(shell mkdir grpc_gen)
endif
	source .venv/bin/activate; \
	python -m grpc_tools.protoc \
		-I$(TAPASCO_HOME_RUNTIME)/libtapasco/protos \
		--python_out=grpc_gen \
		--grpc_python_out=grpc_gen \
		sim_calls.proto status_core.proto read_write.proto
	sed "s/import status_core_pb2 as status__core__pb2/from . import status_core_pb2 as status__core__pb2/" -i grpc_gen/sim_calls_pb2.py
	sed "s/import read_write_pb2 as read__write__pb2/from . import read_write_pb2 as read__write__pb2/" -i grpc_gen/sim_calls_pb2.py
	sed "s/import sim_calls_pb2 as sim__calls__pb2/from . import sim_calls_pb2 as sim__calls__pb2/" -i grpc_gen/sim_calls_pb2_grpc.py
	sed "s/import read_write_pb2 as read__write__pb2/from . import read_write_pb2 as read__write__pb2/" -i grpc_gen/sim_calls_pb2_grpc.py

clean_viv: clean
	rm -rf user_ip
	rm -rf simulate_testbench.*

vivado_prj: clean_viv
	vivado -source create_sim_verilog.tcl -mode batch -tclargs --sim-ip $(SIM_IP) --ip-defs $(IP_DEFS) --board-part $(BOARD_PART)
	mkdir simulate_testbench.sim/sim_1/behav/questa/modelsim_lib/
	mkdir sim_build
	cp compile_simlib/questa/modelsim.ini sim_build/
