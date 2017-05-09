#
# Copyright (C) 2014 Jens Korinth, TU Darmstadt
#
# This file is part of Tapasco (TPC).
#
# Tapasco is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Tapasco is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
#
# @file   simulation_mem_master.tcl
# @brief  Plugin to add a AXI BFM master instance to access memory in Zynq sim.
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval simulation {
  proc create_mem_master {} {
    # create additional AXI BFM master to control memory in sim
    if {[tapasco::get_generate_mode] == "sim"} {
      puts "Creating AXI BFM Master to connect to the ACP port for memory access ..."
      set ps [get_bd_cell -hierarchical -filter {VLNV =~ "xilinx.com:ip:processing_system*"}]
      set axi_bfm [tapasco::createAxiBFM "axi_bfm_mem_master"]
      set axi_bfm_ic [tapasco::createInterconnect "axi_bfm_ic" 1 1]

      # activate HP3 port
      set_property -dict [list \
          CONFIG.PCW_USE_S_AXI_HP3 {1}\
          CONFIG.PCW_S_AXI_HP3_DATA_WIDTH {32}\
	] $ps
      set s_port [get_bd_intf_pins -of_objects $ps -filter {NAME =~ "*HP3"}]
  
      set_property -dict [list \
          CONFIG.C_DISABLE_RESET_VALUE_CHECKS {1} \
	  CONFIG.C_FUNCTION_LEVEL_INFO {0} \
	  CONFIG.C_CHANNEL_LEVEL_INFO {0} \
	  CONFIG.C_PROTOCOL_SELECTION {0} \
	  CONFIG.C_INTERCONNECT_M_AXI3_READ_ISSUING {32} \
	  CONFIG.C_RESPONSE_TIMEOUT {0} \
	  CONFIG.C_M_AXI3_ID_WIDTH {6}\
	] $axi_bfm

      # deactivate register slice (not supported?)
      set_property -dict [list CONFIG.S00_HAS_REGSLICE {0}] $axi_bfm_ic
  
      connect_bd_intf_net [tapasco::get_aximm_interfaces $axi_bfm_ic] $s_port
      connect_bd_intf_net [tapasco::get_aximm_interfaces $axi_bfm] [tapasco::get_aximm_interfaces $axi_bfm_ic "Slave"]
      connect_bd_net [get_bd_pin "$ps/FCLK_CLK0"] \
        [get_bd_pins "$axi_bfm/*" -filter {TYPE == "clk" && DIR == "I"}] \
	[get_bd_pins "$axi_bfm_ic/*" -filter {TYPE == "clk" && DIR == "I"}] \
	[get_bd_pins "$ps/*" -filter {TYPE == "clk" && DIR == "I" && NAME =~ "*HP3*"}]

      set rst [get_bd_pins -of_objects [get_bd_nets -of_objects [get_bd_pins "/Threadpool/peripheral_aresetn"]] -filter {DIR == "O"}]
      connect_bd_net $rst \
        [get_bd_pins "$axi_bfm/*" -filter {TYPE == "rst" && DIR == "I"}] \
	[get_bd_pins "$axi_bfm_ic/*" -filter {TYPE == "rst" && DIR == "I" && NAME != "ARESETN"}]
      set ic_rst [get_bd_pins -of_objects [get_bd_nets -of_objects [get_bd_pins "/Threadpool/interconnect_aresetn"]] -filter {DIR == "O"}]
      connect_bd_net $ic_rst [get_bd_pins "$axi_bfm_ic/ARESETN"]
      
      return $axi_bfm
    }
  }
}

tapasco::register_plugin "platform::zynq::simulation::create_mem_master" "post-bd"
