namespace eval helper {
  namespace export print_version

  proc print_version {args} {
    puts "----------------------------------------------------------------------"
    puts "TaPaSCo version: [exec git rev-parse --short HEAD] @ [exec git rev-parse --abbrev-ref HEAD]"
    puts "----------------------------------------------------------------------"
  }

}

tapasco::register_plugin "platform::helper::print_version" "post-init"

