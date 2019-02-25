# From: hdk/common/shell_v04261818/hlx/build/scripts/create_dcp_from_proj.tcl

namespace eval afi_tarball {

	proc create_tarball {} {

		# TODO: $FAAS_CL_DIR muss gesetzt werden (Projektverzeichnis)
		# TODO: Die Variablen für die Manifest-Datei müssen gesetzt werden
		# TODO: Checkpoint hier erzeugen?

		# Lock the design to preserve the placement and routing
		puts "AWS FPGA: Locking design";
		lock_design -level routing

		# Report final timing
		#bydem - make the directory
		file mkdir $FAAS_CL_DIR/build
		file mkdir $FAAS_CL_DIR/build/reports
		report_timing_summary -file $FAAS_CL_DIR/build/reports/${timestamp}.SH_CL_final_timing_summary.rpt

		# This is what will deliver to AWS
		puts "AWS FPGA: ([clock format [clock seconds] -format %T]) writing final DCP to to_aws directory.";

		file mkdir $FAAS_CL_DIR/build/checkpoints/to_aws

		write_checkpoint -force $FAAS_CL_DIR/build/checkpoints/to_aws/${timestamp}.SH_CL_routed.dcp -encrypt

		# close_project

		puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Compress files for sending to AWS. "

		# Create manifest file
		set manifest_file [open "$FAAS_CL_DIR/build/checkpoints/to_aws/${timestamp}.manifest.txt" w]

		puts "Getting hash"
		set hash [lindex [split [exec sha256sum $FAAS_CL_DIR/build/checkpoints/to_aws/${timestamp}.SH_CL_routed.dcp] ] 0]

		set vivado_version [string range [version -short] 0 5]
		puts "vivado_version is $vivado_version\n"

		puts $manifest_file "manifest_format_version=2\n"
		puts $manifest_file "pci_vendor_id=$vendor_id\n"
		puts $manifest_file "pci_device_id=$device_id\n"
		puts $manifest_file "pci_subsystem_id=$subsystem_id\n"
		puts $manifest_file "pci_subsystem_vendor_id=$subsystem_vendor_id\n"
		puts $manifest_file "dcp_hash=$hash\n"
		puts $manifest_file "shell_version=$shell_version\n"
		puts $manifest_file "tool_version=v$vivado_version\n"
		puts $manifest_file "dcp_file_name=${timestamp}.SH_CL_routed.dcp\n"
		puts $manifest_file "hdk_version=$hdk_version\n"
		puts $manifest_file "date=$timestamp\n"
		puts $manifest_file "clock_recipe_a=$clock_recipe_a\n"
		puts $manifest_file "clock_recipe_b=$clock_recipe_b\n"
		puts $manifest_file "clock_recipe_c=$clock_recipe_c\n"

		close $manifest_file

		# Delete old tar file with same name
		if { [file exists $FAAS_CL_DIR/build/checkpoints/to_aws/${timestamp}.Developer_CL.tar] } {
			puts "Deleting old tar file with same name.";
			file delete -force $FAAS_CL_DIR/build/checkpoints/to_aws/${timestamp}.Developer_CL.tar
		}

		# Tar checkpoint to aws
		cd $FAAS_CL_DIR/build/checkpoints
		tar::create to_aws/${timestamp}.Developer_CL.tar [glob to_aws/${timestamp}*]

		puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Finished creating final tar file in to_aws directory.";
	}

}

tapasco::register_plugin "platform::afi_tarball::create_tarball" "post-impl"
