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
      set versal_cips [get_bd_cells "versal_cips_0"]
      set desc_gen [get_bd_cells "desc_gen_0"]

      connect_bd_intf_net [get_bd_intf_pins $versal_cips/dma0_st_rx_msg] [get_bd_intf_pins $desc_gen/st_rx_msg]

      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_vld] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_valid]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_rdy] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_ready]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_addr] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_addr]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_error] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_error]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_qid] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_qid]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_func] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_func]
      connect_bd_net [get_bd_pins $desc_gen/c2h_byp_st_port_id] [get_bd_pins $versal_cips/dma0_c2h_byp_in_st_sim_port_id]

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

      current_bd_instance $old_bd_inst
      return args
    }
  }

  tapasco::register_plugin "platform::versal::add_streaming_connections" "pre-wiring"
}
