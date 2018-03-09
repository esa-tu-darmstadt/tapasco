# create a dictionary of compatible VLNVs
source $::env(TAPASCO_HOME)/common/common_ip.tcl
dict set stdcomps   dualdma          vlnv   "esa.informatik.tu-darmstadt.de:user:dual_dma:1.10"
dict set stdcomps   axi_pcie3_0_usp  vlnv   "xilinx.com:ip:xdma:4.0"
