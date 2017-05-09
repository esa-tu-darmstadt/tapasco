VLOG = vlog
COMMON_FLAGS = -novopt -hazards -pedanticerrors -64
VLOG_FLAGS = $(COMMON_FLAGS) -lint -fsmverbose t -vlog01compat
VSIM = vsim
VSIM_FLAGS = $(COMMON_FLAGS) -c -do """run -all"""

V_FILES = src/oled_performance_counters.v sim/oled_performance_counters_tb.v sim/oled_bfm.v sim/spireceiver.v src/oled_init.v sim/oled_init_testbench.v src/oled_pc.v sim/oled_pc_tb.v

.PHONY: clean a compile_v_files sim

compile_v_files:	work $(V_FILES)
	$(VLOG) $(VLOG_FLAGS) $(V_FILES)

sim:	compile_v_files
	$(VSIM) $(VSIM_FLAGS) work.oled_pc_tb

oledsim:	compile_v_files
	$(VSIM) $(VSIM_FLAGS) work.oled_performance_counters_tb

work:
	vlib work

clean:
	@rm -rf work screendump.txt vsim.wlf transcript

