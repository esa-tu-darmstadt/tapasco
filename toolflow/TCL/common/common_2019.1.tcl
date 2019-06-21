# create a dictionary of compatible VLNVs
source $::env(TAPASCO_HOME_TCL)/common/common_ip.tcl
dict set stdcomps   system_ila       vlnv   "xilinx.com:ip:system_ila:1.1"
dict set stdcomps   axi_pcie3_0_usp  vlnv   "xilinx.com:ip:xdma:4.1"
dict set stdcomps   clk_wiz          vlnv   "xilinx.com:ip:clk_wiz:6.0"
dict set stdcomps   mig_core         vlnv   "xilinx.com:ip:mig_7series:4.2"
dict set stdcomps   ultra_ps         vlnv   "xilinx.com:ip:zynq_ultra_ps_e:3.3"
