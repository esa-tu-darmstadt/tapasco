puts "Running opt_design post hook..."

if {[info exist FAAS_CL_DIR] eq 0} {
  if {[info exist ::env(FAAS_CL_DIR)]} {
    set FAAS_CL_DIR $::env(FAAS_CL_DIR)
  } else {
    send_msg_id "opt_design_post 0-1" ERROR "FAAS_CL_DIR environment varaiable not set"
  }
}

source [file join $::env(HDK_SHELL_DIR) hlx build scripts subscripts apply_debug_constraints_hlx.tcl]

# "This ensures that there are no contentions on clock nets for designs that have large number of clock nets."
# from `hdk/docs/AWS_Shell_V1.4_Migration_Guidelines.md`
set_param hd.clockRoutingWireReduction false

set timestamp $::env(timestamp)
#write_checkpoint -force $FAAS_CL_DIR/build/checkpoints/${timestamp}.SH_CL.post_opt.dcp

# vim: set expandtab ts=2 sw=2:
