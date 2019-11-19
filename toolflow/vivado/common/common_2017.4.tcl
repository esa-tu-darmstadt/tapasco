# create a dictionary of compatible VLNVs
source $::env(TAPASCO_HOME_TCL)/common/common_ip.tcl
dict set stdcomps   system_ila       vlnv   "xilinx.com:ip:system_ila:1.1"
dict set stdcomps   axi_pcie3_0_usp  vlnv   "xilinx.com:ip:xdma:4.0"
