# Copyright (c) 2014-2022 Embedded Systems and Applications, TU Darmstadt.
#
# This file is part of TaPaSCo
# (see https://github.com/esa-tu-darmstadt/tapasco).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

# create a dictionary of compatible VLNVs
source $::env(TAPASCO_HOME_TCL)/common/common_ip.tcl
dict set stdcomps   system_ila       vlnv   "xilinx.com:ip:system_ila:1.1"
dict set stdcomps   axi_pcie3_0_usp  vlnv   "xilinx.com:ip:xdma:4.1"
dict set stdcomps   clk_wiz          vlnv   "xilinx.com:ip:clk_wiz:6.0"
dict set stdcomps   mig_core         vlnv   "xilinx.com:ip:mig_7series:4.2"
dict set stdcomps   ultra_ps         vlnv   "xilinx.com:ip:zynq_ultra_ps_e:3.4"
dict set stdcomps   xxv_ethernet     vlnv   "xilinx.com:ip:xxv_ethernet:4.1"
dict set stdcomps   100g_ethernet    vlnv   "xilinx.com:ip:cmac_usplus:3.1"
dict set stdcomps   aurora           vlnv   "xilinx.com:ip:aurora_64b66b:12.0"
dict set stdcomps   system_cache     vlnv   "xilinx.com:ip:system_cache:5.0"
dict set stdcomps   axi_cache        vlnv   "xilinx.com:ip:system_cache:5.0"
dict set stdcomps   util_buf         vlnv   "xilinx.com:ip:util_ds_buf:2.2"
dict set stdcomps   axi_iic          vlnv   "xilinx.com:ip:axi_iic:2.1"
dict set stdcomps   hbm              vlnv   "xilinx.com:ip:hbm:1.0"
dict set stdcomps   versal_cips      vlnv   "xilinx.com:ip:versal_cips:3.3"
dict set stdcomps   axi_noc          vlnv   "xilinx.com:ip:axi_noc:1.0"
dict set stdcomps   mrmac            vlnv   "xilinx.com:ip:mrmac:2.0"
dict set stdcomps   qdma             vlnv   "xilinx.com:ip:qdma:5.0"