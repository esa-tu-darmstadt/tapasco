set name [lindex $argv 0]
set version [lindex $argv 1]
ipx::infer_core -vendor de.tu-darmstadt.cs.esa.tapasco -library tapasco -name $name -version $version .
set_property taxonomy "TaPaSCo" [ipx::current_core]
set_property display_name $name [ipx::current_core]
set_property supported_families [list zynq Pre-Production \
                                      virtex7 Pre-Production \
                                      artix7 Pre-Production \
                                      kintex7 Pre-Production] [ipx::current_core]
ipx::create_xgui_files -logo_file $::env(TAPASCO_HOME)/icon/tapasco_icon_small.png [ipx::current_core]
ipx::save_core
exit
