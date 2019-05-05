set workdir [file dirname [file normalize [info script]]]
cd $workdir
# /home/mober/projects/tapasco/aws_intc
puts "Working directory: $workdir"

file mkdir ipcore/src
file mkdir repository
file copy -force verilog/mkAWSInterruptCtrl.v ipcore

create_project tmpproj -force tmpproj

ipx::infer_core -vendor user.org -library user -taxonomy /UserIP ipcore

ipx::edit_ip_in_project -upgrade true -name edit_ip_project -directory tmpproj/tmpproj.tmp ipcore/component.xml

ipx::current_core ipcore/component.xml

add_files -norecurse -force -copy_to ipcore/src /opt/cad/bluespec/latest/lib/Verilog/FIFO2.v
update_compile_order -fileset sources_1

# -generated_files -import_files -force
# -vendor user.org -library user -taxonomy /UserIP
ipx::package_project -root_dir ipcore -force -generated_files -import_files

# set core [ipx::current_core]

# # Basic information
# set_property vendor esa.informatik.tu-darmstadt.de $core
# set_property library tapasco $core
# set_property display_name "$project_name Processing Element" $core
# set_property description "PE containing $project_name RISC-V processor" $core
# set_property vendor_display_name {ESA TU Darmstadt} $core

# # Interfaces
# set_property name interrupt [ipx::get_bus_interfaces INTR.INTERRUPT -of_objects $core]
# set_property name CLK [ipx::get_bus_interfaces CLK.CLK -of_objects $core]
# ipx::remove_bus_parameter FREQ_HZ [ipx::get_bus_interfaces CLK -of_objects $core]
# ipx::remove_bus_parameter PHASE [ipx::get_bus_interfaces CLK -of_objects $core]
# set_property name ARESET_N [ipx::get_bus_interfaces RST.ARESET_N -of_objects $core]


ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core mkAWSInterruptCtrl_1.0.zip [ipx::current_core]

close_project

file delete -force ipcore
file delete -force tmpproj
