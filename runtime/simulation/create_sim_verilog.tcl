if { $::argc > 0 } {
  for {set i 0} { $i < [llength $::argv] } { incr i } {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--sim-ip" { incr i; set sim_ip [lindex $::argv $i]}
      "--board-part" {incr i; set board_part [lindex $::argv $i]}
      "--ip-defs" {incr i; set ip_defs [lindex $::argv $i]}
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified.\n"
          return 1
        }
      }
    }
  }
}
create_project -part $board_part simulate_testbench -force
exec mkdir -p user_ip
set_property IP_REPO_PATHS "[pwd]/user_ip" [current_project]
update_ip_catalog
update_ip_catalog -add_ip $sim_ip -repo_path [pwd]/user_ip
set pe [create_ip -module_name pe -vlnv [get_ipdefs $ip_defs]]
generate_target all $pe

# find top
set_property top [lindex [find_top] 0] [get_filesets sim_1]

set_property target_simulator Questa [current_project]
set_property compxlib.questa_compiled_library_dir {compile_simlib/questa} [current_project]

launch_simulation -scripts_only -absolute_path
