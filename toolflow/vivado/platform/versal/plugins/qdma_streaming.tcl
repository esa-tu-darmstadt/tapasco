# Copyright (c) 2014-2024 Embedded Systems and Applications, TU Darmstadt.
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

if {[tapasco::is_feature_enabled "DMA-Streaming"]} {
  namespace eval versal {
    proc add_streaming_connections {{args {}}} {
      set old_bd_inst [current_bd_instance .]

      current_bd_instance "/host"
      set host_clk [get_bd_pins /clocks_and_resets/host_clk]
      set design_clk [get_bd_pins /clocks_and_resets/design_clk]
      set host_aresetn [get_bd_pins /clocks_and_resets/host_peripheral_aresetn]
      set design_aresetn [get_bd_pins /clocks_and_resets/design_peripheral_aresetn]
      set versal_cips [get_bd_cells "versal_cips_0"]
      set desc_gen [get_bd_cells "desc_gen_0"]

      # create ports for AXI Stream to user PE
      set m_axis_dma [create_bd_intf_pin -mode Master -vlnv "xilinx.com:interface:axis_rtl:1.0" "M_AXIS_H2C_DMA"]
      set s_axis_dma [create_bd_intf_pin -mode Slave -vlnv "xilinx.com:interface:axis_rtl:1.0" "S_AXIS_C2H_DMA"]

      connect_bd_intf_net [get_bd_intf_pins $versal_cips/dma0_st_rx_msg] [get_bd_intf_pins $desc_gen/st_rx_msg]

      # C2H Stream descriptor bypass interface
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_vld] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_valid]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_rdy] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_ready]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_addr] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_addr]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_error] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_error]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_qid] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_qid]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_func] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_func]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_port_id] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_port_id]

      # H2C Stream descriptor bypass interface
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_vld] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_valid]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_rdy] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_ready]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_addr] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_addr]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_len] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_len]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_no_dma] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_no_dma]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_error] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_error]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_sdi] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_sdi]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_mrkr_req] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_mrkr_req]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_sop] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_sop]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_eop] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_eop]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_qid] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_qid]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_func] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_func]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_cidx] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_cidx]
      connect_bd_net [get_bd_pins $desc_gen/h2c_byp_st_port_id] [get_bd_pins $versal_cips/dma0_h2c_byp_in_st_port_id]

      connect_bd_intf_net [get_bd_intf_pins $desc_gen/axis_c2h] [get_bd_intf_pins $versal_cips/dma0_s_axis_c2h]
      connect_bd_intf_net [get_bd_intf_pins $desc_gen/axis_c2h_cmpt] [get_bd_intf_pins $versal_cips/dma0_s_axis_c2h_cmpt]
      connect_bd_intf_net [get_bd_intf_pins $versal_cips/dma0_m_axis_h2c] [get_bd_intf_pins $desc_gen/axis_h2c]

      # add interconnect between descriptor generator and user PE
      set axis_h2c_ic [tapasco::ip::create_axis_ic axis_dma_h2c_ic_0 1 1]
      set axis_c2h_ic [tapasco::ip::create_axis_ic axis_dma_c2h_ic_0 1 1]
      connect_bd_intf_net [get_bd_intf_pins $desc_gen/M_AXIS_USER] [get_bd_intf_pins $axis_h2c_ic/S00_AXIS]
      connect_bd_intf_net [get_bd_intf_pins $axis_h2c_ic/M00_AXIS] $m_axis_dma
      connect_bd_intf_net $s_axis_dma [get_bd_intf_pins $axis_c2h_ic/S00_AXIS]
      connect_bd_intf_net [get_bd_intf_pins $axis_c2h_ic/M00_AXIS] [get_bd_intf_pins $desc_gen/S_AXIS_USER]
      connect_bd_net $host_clk [get_bd_pins $axis_h2c_ic/ACLK] [get_bd_pins $axis_h2c_ic/S00_AXIS_ACLK] \
        [get_bd_pins $axis_c2h_ic/ACLK] [get_bd_pins $axis_c2h_ic/M00_AXIS_ACLK]
      connect_bd_net $host_aresetn [get_bd_pins $axis_h2c_ic/ARESETN] [get_bd_pins $axis_h2c_ic/S00_AXIS_ARESETN] \
        [get_bd_pins $axis_c2h_ic/ARESETN] [get_bd_pins $axis_c2h_ic/M00_AXIS_ARESETN]
      connect_bd_net $design_clk [get_bd_pins $axis_h2c_ic/M00_AXIS_ACLK] [get_bd_pins $axis_c2h_ic/S00_AXIS_ACLK]
      connect_bd_net $design_aresetn [get_bd_pins $axis_h2c_ic/M00_AXIS_ARESETN] [get_bd_pins $axis_c2h_ic/S00_AXIS_ARESETN]

      # connect stream ports of user PE
      current_bd_instance "/arch"
      set m_axis_dma_arch [create_bd_intf_pin -mode Master -vlnv "xilinx.com:interface:axis_rtl:1.0" "M_AXIS_C2H_DMA"]
      set s_axis_dma_arch [create_bd_intf_pin -mode Slave -vlnv "xilinx.com:interface:axis_rtl:1.0" "S_AXIS_H2C_DMA"]
      set user_master [tapasco::get_feature_option "DMA-Streaming" "master_port" -1]
      set user_slave [tapasco::get_feature_option "DMA-Streaming" "slave_port" -1]
      set pes [get_bd_cells -filter "NAME =~ *target_ip_*_* && TYPE == ip" -of_objects [get_bd_cells /arch]]
      if {$user_master != -1} {
        set pe_master_ifcs [get_bd_intf_pins -of_objects $pes -filter "vlnv == xilinx.com:interface:axis_rtl:1.0 && MODE == Master && PATH =~ *$user_master"]
        if {[llength $pe_master_ifcs] < 1} {
          exit 1
        }
        foreach intf $pe_master_ifcs {
          connect_bd_intf_net $intf $m_axis_dma_arch
        }
      }
      if {$user_slave != -1} {
        set pe_slave_ifcs [get_bd_intf_pins -of_objects $pes -filter "vlnv == xilinx.com:interface:axis_rtl:1.0 && MODE == Slave && PATH =~ *$user_slave"]
        if {[llength $pe_slave_ifcs] < 1} {
          puts "ERROR: Specified slave interface not found"
          exit 1
        }
        foreach intf $pe_slave_ifcs {
          puts "connect interfaces: $intf to $s_axis_dma_arch"
          connect_bd_intf_net $intf $s_axis_dma_arch
        }
      }

      current_bd_instance $old_bd_inst
      return args
    }
  }

  tapasco::register_plugin "platform::versal::add_streaming_connections" "pre-wiring"
}
