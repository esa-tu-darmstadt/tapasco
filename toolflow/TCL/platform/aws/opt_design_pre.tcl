puts "Running opt_design pre hook..."

if {[info exist FAAS_CL_DIR] eq 0} {
  if {[info exist ::env(FAAS_CL_DIR)]} {
    set FAAS_CL_DIR $::env(FAAS_CL_DIR)
  } else {
    send_msg_id "opt_design_pre 0-1" ERROR "FAAS_CL_DIR environment varaiable not set"
  }
}

set top top_sp
set timestamp $::env(timestamp)

write_checkpoint -force $FAAS_CL_DIR/build/checkpoints/CL.post_synth_inline.dcp

report_property [current_design]

add_files $::env(HDK_SHELL_DIR)/build/checkpoints/from_aws/SH_CL_BB_routed.dcp

add_files $FAAS_CL_DIR/build/checkpoints/CL.post_synth.dcp
set_property SCOPED_TO_CELLS {WRAPPER_INST/CL} [get_files $FAAS_CL_DIR/build/checkpoints/CL.post_synth.dcp]


read_xdc $::env(HDK_SHELL_DIR)/build/constraints/cl_ddr.xdc

set PNR_USR_LOC $::env(PNR_USER)
read_xdc ${PNR_USR_LOC}
set_property PROCESSING_ORDER LATE [get_files $PNR_USR_LOC]
set_property USED_IN {implementation} [get_files $PNR_USR_LOC]

link_design -top $top -part [get_parts -of_objects [current_project]] \
  -reconfig_partitions {WRAPPER_INST/SH WRAPPER_INST/CL}

set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets WRAPPER_INST/SH/kernel_clks_i/clkwiz_sys_clk/inst/CLK_CORE_DRP_I/clk_inst/clk_out2]
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets WRAPPER_INST/SH/kernel_clks_i/clkwiz_sys_clk/inst/CLK_CORE_DRP_I/clk_inst/clk_out3]

#source ${FAAS_CL_DIR}/build/constraints/aws_gen_clk_constraints.tcl
source $::env(TAPASCO_HOME_TCL)/platform/aws/constraints/125/aws_gen_clk_constraints.tcl

source $::env(HDK_SHELL_DIR)/build/scripts/check_uram.tcl

write_checkpoint -force $FAAS_CL_DIR/build/checkpoints/${timestamp}.SH_CL.post_link_design.dcp

# vim: set expandtab ts=2 sw=2:
