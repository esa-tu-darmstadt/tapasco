puts "Running opt_design post hook..."

if {[info exist FAAS_CL_DIR] eq 0} {
	if {[info exist ::env(FAAS_CL_DIR)]} {
		set FAAS_CL_DIR $::env(FAAS_CL_DIR)
	} else {
    send_msg_id "opt_design_post 0-1" ERROR "FAAS_CL_DIR environment varaiable not set"
  }
}

set_param hd.clockRoutingWireReduction false

#set timestamp $::env(timestamp)
write_checkpoint -force $FAAS_CL_DIR/build/checkpoints/SH_CL.post_opt.dcp

# vim: set expandtab ts=2 sw=2:

