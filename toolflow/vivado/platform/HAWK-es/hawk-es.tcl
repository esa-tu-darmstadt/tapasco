if {[version -short] != "2021.2"} {
  puts "Only Vivado 2021.2 is currently supported for Versal ES devices."
  exit 1
}

source [file dirname [info script]]/../HAWK/hawk.tcl
