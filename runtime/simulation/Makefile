ifeq ($(MAKECMDGOALS),)
  $(shell pkill -f -u $(USER) questa)
endif
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


configure:
	python -m venv .venv
	source .venv/bin/activate; \
	pip install -r requirements.txt

test: sim
	python3 combine_results.py

simlib_questa:
	echo "compile_simlib -simulator questa -simulator_exec_path {/opt/cad/mentor/questa/questa-2021.3/questasim/bin} -gcc_exec_path {/opt/cad/mentor/questa/questa-2021.3/questasim/gcc-7.4.0-linux_x86_64/bin} -family zynquplus -language all -library all -dir {compile_simlib/questa}" > questa.tcl
	vivado -nojournal -nolog -mode batch -source questa.tcl

simlib_ies:
	echo "compile_simlib -simulator ies -simulator_exec_path {/opt/cad/cadence/2016-17/RHELx86/INCISIVE_15.20.010/bin} -family all -language all -library all -dir {compile_simlib/ies}" > ies.tcl
	vivado -nojournal -nolog -mode batch -source ies.tcl

simulate_ies:
	simulate_testbench.sim/sim_1/behav/ies/setup.sh
	simulate_testbench.sim/sim_1/behav/ies/compile.sh
	# change -timescale 1ps/1ps
	simulate_testbench.sim/sim_1/behav/ies/elaborate.sh
	simulate_testbench.sim/sim_1/behav/ies/simulate.sh

protos: $(if $(CONFIGURE_NEEDED),configure)
ifeq ($(wildcard grpc_gen),)
	$(shell mkdir grpc_gen)
endif
	source .venv/bin/activate; \
	which python; \
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
