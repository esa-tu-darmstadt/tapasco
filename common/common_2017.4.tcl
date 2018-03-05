# create a dictionary of compatible VLNVs
source $::env(TAPASCO_HOME)/common/common_ip.tcl
dict set stdcomps   dualdma          vlnv   "esa.informatik.tu-darmstadt.de:user:dual_dma:1.11"
dict set stdcomps   system_ila       vlnv   "xilinx.com:ip:system_ila:1.1"
