if { [::tapasco::vivado_is_newer "2020.1"] == 1 } {
  puts "Vivado [version -short] is too new to support xupvvh-es."
  exit 1
}