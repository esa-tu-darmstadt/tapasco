puts "Running route_design post hook..."

write_debug_probes -force -no_partial_ltxfile -file [file join $::env(FAAS_CL_DIR) build checkpoints to_aws "${::env(timestamp)}.debug_probes.ltx"]

# vim: set expandtab ts=2 sw=2:
