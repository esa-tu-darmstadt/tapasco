puts "Running opt_design post hook..."

source [file join $::env(HDK_SHELL_DIR) hlx build scripts subscripts apply_debug_constraints_hlx.tcl]

# "This ensures that there are no contentions on clock nets for designs that have large number of clock nets."
# from `hdk/docs/AWS_Shell_V1.4_Migration_Guidelines.md`
set_param hd.clockRoutingWireReduction false

# vim: set expandtab ts=2 sw=2:
