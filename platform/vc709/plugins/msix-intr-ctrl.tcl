namespace eval msix_intr_ctrl {
  proc simplify_routing {} {
    read_xdc "$::env(TAPASCO_HOME)/common/ip/MSIXIntrCtrl/msix_intr_ctrl.xdc"
  }
}

tapasco::register_plugin "platform::msix_intr_ctrl::simplify_routing" "post-synth"
