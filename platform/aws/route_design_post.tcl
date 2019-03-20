puts "Running route_design post hook..."

if {[info exist FAAS_CL_DIR] eq 0} {
	if {[info exist ::env(FAAS_CL_DIR)]} {
		set FAAS_CL_DIR $::env(FAAS_CL_DIR)
	} else {
    send_msg_id "route_design_post 0-1" ERROR "FAAS_CL_DIR environment varaiable not set"
  }
}

# TODO this checkpoint may be useless because it is overwritten later in the flow (create_tarfile)

set timestamp $::env(timestamp)
write_checkpoint -force $FAAS_CL_DIR/build/checkpoints/to_aws/${timestamp}.SH_CL_routed.dcp -encrypt

# vim: set expandtab ts=2 sw=2:

