namespace eval blue_dma {
  namespace export blue_dma
  namespace export set_constraints

  set vlnv "esa.informatik.tu-darmstadt.de:user:BlueDMA:1.0"

  proc blue_dma {{args {}}} {
    variable vlnv
    if {[tapasco::is_feature_enabled "BlueDMA"]} {
      # blue_dma is drop-in replacement for dual_dma: replace original VLNV
      dict set tapasco::stdcomps dualdma vlnv $vlnv
    }
  }

  proc set_constraints {{args {}}} {
    if {[tapasco::is_feature_enabled "BlueDMA"]} {
      puts "Adding false path constraints for BlueDMA"
      set constraints_fn "[get_property DIRECTORY [current_project]]/bluedma.xdc"
      set constraints_file [open $constraints_fn w+]
      puts $constraints_file {set s_clk [get_clocks -of_objects [get_ports m32_axi_aclk]]}
      puts $constraints_file {set m_clk [get_clocks -of_objects [get_ports m64_axi_aclk]]}
      puts $constraints_file {set g_clk [get_clocks -of_objects [get_ports s_axi_aclk]]}
      puts $constraints_file {set_clock_groups -asynchronous -group $g_clk -group $s_clk}
      puts $constraints_file {set_clock_groups -asynchronous -group $g_clk -group $m_clk}
      puts $constraints_file {set_clock_groups -asynchronous -group $m_clk -group $s_clk}
      close $constraints_file
      read_xdc -cells {system_i/Memory/dual_dma} $constraints_fn
    } 
    return {}
  }
}

tapasco::register_plugin "platform::blue_dma::blue_dma" "post-init"
tapasco::register_plugin "platform::blue_dma::set_constraints" "post-synth"
