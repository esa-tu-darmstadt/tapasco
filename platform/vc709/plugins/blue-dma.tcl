namespace eval blue_dma {
  namespace export blue_dma
  namespace export set_constraints

  set vlnv "esa.informatik.tu-darmstadt.de:user:BlueDMA:1.0"

  proc blue_dma {{args {}}} {
    variable vlnv
    if {[tapasco::is_feature_enabled "BlueDMA"]} {
      # blue_dma is drop-in replacement for dual_dma: replace original VLNV
      dict set tapasco::ip::stdcomps dualdma vlnv $vlnv
    }
  }
}

tapasco::register_plugin "platform::blue_dma::blue_dma" "post-init"
