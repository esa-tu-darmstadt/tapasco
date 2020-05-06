namespace eval helper {
  namespace export print_version

  proc print_version {args} {
    set c [file join $::env(TAPASCO_HOME) .git]
    puts "----------------------------------------------------------------------"
    puts "TaPaSCo version:"
    puts "[exec git --git-dir $c log -1 --oneline --no-color]"
    puts "----------------------------------------------------------------------"
  }

}

tapasco::register_plugin "platform::helper::print_version" "post-init"

