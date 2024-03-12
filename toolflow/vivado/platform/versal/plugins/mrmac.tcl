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

namespace eval mrmac {
  proc is_mrmac_supported {} {
    return false
  }

  # @return the number of physical ports available on this platform
  proc num_available_ports {} {
    return 0
  }

  proc get_mrmac_locations {} {
    return {}
  }

  proc get_refclk_freq {} {
    return 161.1328125
  }
}

namespace eval sfpplus {
  proc is_sfpplus_supported {} {
    return [platform::mrmac::is_mrmac_supported]
  }

  proc get_available_modes {} {
    return {"100G"}
  }

  proc num_available_ports {mode} {
    if {$mode == "100G"} {
      return [platform::mrmac::num_available_ports]
    }
    puts "Invalid SFP+ mode: mode $mode is not supported by this platform. Available modes are: 100G"
    exit
  }

  proc generate_cores {mode physical_ports} {
    if {$mode != "100G"} {
      error "$mode is not supported"
    }
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/versal/plugins/mrmac.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]

    # iterate over all configured ports
  foreach port [dict keys $physical_ports] {
    # need to be in / for bd_automation to work
    set old_bd /network
    current_bd_instance /

    set name [dict get $physical_ports $port]
    puts "Port name $port: $name"

    set old_bd_cells [get_bd_cells]
    set mrmac [tapasco::ip::create_mrmac "mrmac_$name"]

    # valid options 256, 384, 384segmented
    set datawidth [tapasco::get_feature_option "SFPPLUS" "datawidth" "256"]
    set dw_index 0
    set bitwidth 256
    set bytewidth 32
    if {$datawidth == "256"} {
        set dw_index 0
        set bitwidth 256
        set bytewidth 32
    } elseif {$datawidth == "384"} {
        set dw_index 1
        set bitwidth 384
        set bytewidth 48
    } elseif {$datawidth == "384segmented"} {
        set dw_index 2
        set bitwidth 384
        set bytewidth 48
    }
    # parameter MRMAC_DATA_PATH_INTERFACE_C0 is for MRMAC:1.5
    set datawidth_v1 [list {256b Non-Segmented} {384b Non-Segmented} {384b Segmented}]
    # parameter MRMAC_DATA_PATH_INTERFACE_PORT0_C0 is for MRMAC:2.1
    set datawidth_v2 [list {Low Latency 256b Non-Segmented} {Independent 384b Non-Segmented} {Independent 384b Segmented}]
    puts "MRMAC configured to datawidth [lindex $datawidth_v2 $dw_index]"
    set_property -dict [list \
      CONFIG.MRMAC_LOCATION_C0 [lindex [platform::mrmac::get_mrmac_locations] $port] \
      CONFIG.MRMAC_DATA_PATH_INTERFACE_C0 [lindex $datawidth_v1 $dw_index] \
      CONFIG.MRMAC_DATA_PATH_INTERFACE_PORT0_C0 [lindex $datawidth_v2 $dw_index] \
      CONFIG.GT_REF_CLK_FREQ_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH0_TX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH0_RX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH1_TX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH1_RX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH2_TX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH2_RX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH3_TX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
      CONFIG.GT_CH3_RX_REFCLK_FREQUENCY_C0 [platform::mrmac::get_refclk_freq] \
    ] $mrmac

    apply_bd_automation -rule xilinx.com:bd_rule:mrmac -config { DataPath_Interface_Connection {Auto} Lane0_selection {NULL} Lane1_selection {NULL} Lane2_selection {NULL} Lane3_selection {NULL} Quad0_selection {NULL} Quad1_selection {NULL} Quad2_selection {NULL} Quad3_selection {NULL}} $mrmac

    # ref clock at /
    set ref_port [create_bd_intf_port -vlnv xilinx.com:interface:diff_clock_rtl:1.0 -mode Slave qsfp${port}_ref]

    set current_bd_cells [get_bd_cells]
    puts $old_bd_cells
    # delete all external connections from block automation
    foreach cell $current_bd_cells {
      if {[lsearch $old_bd_cells $cell] == -1} {
        delete_bd_objs -quiet [get_bd_ports -of_objects [get_bd_nets -of_objects [get_bd_pins -of_objects $cell]]]
        delete_bd_objs -quiet [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects [get_bd_intf_pins -of_objects $cell]]]
      }
    }
    puts $ref_port
    puts  [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
    set subcell [create_bd_cell -type hier $old_bd/mrmac_${name}_cell]
    connect_bd_intf_net [get_bd_intf_ports $ref_port] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
    # move all newly created cells to subsystem
    foreach cell $current_bd_cells {
      if {[lsearch $old_bd_cells $cell] == -1} {
        # move cell into network subsystem
        move_bd_cells [get_bd_cell $subcell] $cell
      }
    }
    current_bd_instance $subcell

    # create user clock for independent clocking modes
    if {$datawidth == "256"} {
        set user_clk [get_bd_pins -quiet bufg_gt_0/usrclk]
        if {[llength $user_clk] == 0} {
          set user_clk [get_bd_pins mbufg_gt_0/MBUFG_GT_O1]
        }
    } elseif {$datawidth == "384"} {
      if {$datawidth == "384"} {
        set freq {390.625}
      } elseif {$datawidth == "384segmented"} {
        set freq {322.265}
      }
      set user_clk_wiz [tapasco::ip::create_clk_wizard user_clk_wiz]
      connect_bd_net [get_bd_pins bufg_gt_0/usrclk] [get_bd_pins mbufg_gt_0/MBUFG_GT_O1] [get_bd_pins $user_clk_wiz/clk_in1]
      set_property -dict [list \
        CONFIG.PRIMITIVE_TYPE {PLL} \
        CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY $freq \
        CONFIG.CLKOUT_USED {true} \
      ] $user_clk_wiz
      set user_clk [get_bd_pins $user_clk_wiz/clk_out1]
    }
    set user_clk_concat [tapasco::ip::create_xlconcat user_clk_concat 4]
    connect_bd_net $user_clk [get_bd_pins $user_clk_concat/In0] [get_bd_pins $user_clk_concat/In1] [get_bd_pins $user_clk_concat/In2] [get_bd_pins $user_clk_concat/In3]

    set gt_quad_base [get_bd_cell gt_quad_base]
    # transceiver ports
    set p [create_bd_port -dir O -from 3 -to 0 qsfp${port}_txp_out]
    connect_bd_net $p [get_bd_pins $gt_quad_base/txp]
    set p [create_bd_port -dir O -from 3 -to 0 qsfp${port}_txn_out]
    connect_bd_net $p [get_bd_pins $gt_quad_base/txn]
    set p [create_bd_port -dir I -from 3 -to 0 qsfp${port}_rxp_in]
    connect_bd_net $p [get_bd_pins $gt_quad_base/rxp]
    set p [create_bd_port -dir I -from 3 -to 0 qsfp${port}_rxn_in]
    connect_bd_net $p [get_bd_pins $gt_quad_base/rxn]
    connect_bd_net [get_bd_pins $gt_quad_base/gtpowergood] [get_bd_pins $mrmac/gtpowergood_in]
    set tx_clk_concat [tapasco::ip::create_xlconcat tx_clk_concat 4]
    # older versions have bufg_gt_xx, newer version use mbufg_gt_xx; one will be present
    connect_bd_net [get_bd_pins bufg_gt_0/usrclk] [get_bd_pins mbufg_gt_0/MBUFG_GT_O1] [get_bd_pins $tx_clk_concat/In0] [get_bd_pins $tx_clk_concat/In1] [get_bd_pins $tx_clk_concat/In2] [get_bd_pins $tx_clk_concat/In3]
    connect_bd_net [get_bd_pins $tx_clk_concat/dout] [get_bd_pins $mrmac/tx_core_clk] [get_bd_pins $mrmac/tx_serdes_clk]
    set rx_clk_concat [tapasco::ip::create_xlconcat rx_clk_concat 4]
    connect_bd_net [get_bd_pins bufg_gt_1/usrclk] [get_bd_pins mbufg_gt_1/MBUFG_GT_O1] [get_bd_pins $rx_clk_concat/In0]
    connect_bd_net [get_bd_pins bufg_gt_1_1/usrclk] [get_bd_pins mbufg_gt_1_1/MBUFG_GT_O1] [get_bd_pins $rx_clk_concat/In1]
    connect_bd_net [get_bd_pins bufg_gt_1_2/usrclk] [get_bd_pins mbufg_gt_1_2/MBUFG_GT_O1] [get_bd_pins $rx_clk_concat/In2]
    connect_bd_net [get_bd_pins bufg_gt_1_3/usrclk] [get_bd_pins mbufg_gt_1_3/MBUFG_GT_O1] [get_bd_pins $rx_clk_concat/In3]
    connect_bd_net [get_bd_pins $rx_clk_concat/dout] [get_bd_pins $mrmac/rx_core_clk] [get_bd_pins $mrmac/rx_serdes_clk]
    # rx_alt_serdes_clk = {ch3_rx_usr_clk2,ch2_rx_usr_clk2,ch1_rx_usr_clk2,ch0_rx_usr_clk2}:
    set rx_alt_serdes_clk_concat [tapasco::ip::create_xlconcat rx_alt_serdes_clk_concat 4]
    connect_bd_net [get_bd_pins bufg_gt_3/usrclk]   [get_bd_pins mbufg_gt_1/MBUFG_GT_O2] [get_bd_pins rx_alt_serdes_clk_concat/In0]
    connect_bd_net [get_bd_pins bufg_gt_3_1/usrclk] [get_bd_pins mbufg_gt_1_1/MBUFG_GT_O2] [get_bd_pins rx_alt_serdes_clk_concat/In1]
    connect_bd_net [get_bd_pins bufg_gt_3_2/usrclk] [get_bd_pins mbufg_gt_1_2/MBUFG_GT_O2] [get_bd_pins rx_alt_serdes_clk_concat/In2]
    connect_bd_net [get_bd_pins bufg_gt_3_3/usrclk] [get_bd_pins mbufg_gt_1_3/MBUFG_GT_O2] [get_bd_pins rx_alt_serdes_clk_concat/In3]
    connect_bd_net [get_bd_pins rx_alt_serdes_clk_concat/dout] [get_bd_pins $mrmac/rx_alt_serdes_clk] [get_bd_pins $mrmac/rx_flexif_clk] [get_bd_pins $mrmac/rx_ts_clk]
    # tx_alt_serdes_clk = {4{ch0_tx_usr_clk2}};
    set tx_alt_serdes_clk_concat [tapasco::ip::create_xlconcat tx_alt_serdes_clk_concat 4]
    connect_bd_net [get_bd_pins bufg_gt_2/usrclk] [get_bd_pins mbufg_gt_0/MBUFG_GT_O2] [get_bd_pins tx_alt_serdes_clk_concat/In0] [get_bd_pins tx_alt_serdes_clk_concat/In1] [get_bd_pins tx_alt_serdes_clk_concat/In2] [get_bd_pins tx_alt_serdes_clk_concat/In3]
    connect_bd_net [get_bd_pins tx_alt_serdes_clk_concat/dout] [get_bd_pins $mrmac/tx_alt_serdes_clk] [get_bd_pins $mrmac/tx_flexif_clk] [get_bd_pins $mrmac/tx_ts_clk]
    #ch0_tx_usr_clk2:
    connect_bd_net [get_bd_pins bufg_gt_2/usrclk] [get_bd_pins mbufg_gt_0/MBUFG_GT_O2] [get_bd_pins $gt_quad_base/ch0_txusrclk] [get_bd_pins $gt_quad_base/ch1_txusrclk] [get_bd_pins $gt_quad_base/ch2_txusrclk] [get_bd_pins $gt_quad_base/ch3_txusrclk]
    #ch0_rx_usr_clk2:
    connect_bd_net [get_bd_pins bufg_gt_3/usrclk]   [get_bd_pins mbufg_gt_1/MBUFG_GT_O2] [get_bd_pins $gt_quad_base/ch0_rxusrclk]
    connect_bd_net [get_bd_pins bufg_gt_3_1/usrclk] [get_bd_pins mbufg_gt_1_1/MBUFG_GT_O2] [get_bd_pins $gt_quad_base/ch1_rxusrclk]
    connect_bd_net [get_bd_pins bufg_gt_3_2/usrclk] [get_bd_pins mbufg_gt_1_2/MBUFG_GT_O2] [get_bd_pins $gt_quad_base/ch2_rxusrclk]
    #ch3_rx_usr_clk2:
    connect_bd_net [get_bd_pins bufg_gt_3_3/usrclk] [get_bd_pins mbufg_gt_1_3/MBUFG_GT_O2] [get_bd_pins $gt_quad_base/ch3_rxusrclk]
    connect_bd_net $design_aclk [get_bd_pins $mrmac/s_axi_aclk] [get_bd_pins $gt_quad_base/apb3clk]
    if {$datawidth == "256"} {
      # rx_axi_clk and tx_axi_clk are not used but should be half of the core_clk; 644MHz is apparently too fast
      set user_clk4_rx [get_bd_pins $rx_alt_serdes_clk_concat/dout]
      set user_clk4_tx [get_bd_pins $tx_alt_serdes_clk_concat/dout]
    } else {
      set user_clk4_rx [get_bd_pin $user_clk_concat/dout]
      set user_clk4_tx [get_bd_pin $user_clk_concat/dout]
    }
    connect_bd_net $user_clk4_rx [get_bd_pins $mrmac/rx_axi_clk]
    connect_bd_net $user_clk4_tx [get_bd_pins $mrmac/tx_axi_clk]
    # reset
    set rx_res_inv [tapasco::ip::create_logic_vector rx_res_inv]
    set_property -dict [list CONFIG.C_SIZE {4} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] $rx_res_inv
    connect_bd_net [get_bd_pins $mrmac/gt_rx_reset_done_out] [get_bd_pins $rx_res_inv/Op1]
    connect_bd_net [get_bd_pins $rx_res_inv/Res] [get_bd_pins $mrmac/rx_core_reset] [get_bd_pins $mrmac/rx_serdes_reset]
    set tx_res_inv [tapasco::ip::create_logic_vector tx_res_inv]
    set_property -dict [list CONFIG.C_SIZE {4} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] $tx_res_inv
    connect_bd_net [get_bd_pins $mrmac/gt_tx_reset_done_out] [get_bd_pins $tx_res_inv/Op1]
    connect_bd_net [get_bd_pins $tx_res_inv/Res] [get_bd_pins $mrmac/tx_core_reset] [get_bd_pins $mrmac/tx_serdes_reset]
    # workaround: second instance has an undriven net hanging around
    delete_bd_objs -quiet [get_bd_nets -of [get_bd_pin $mrmac/s_axi_aresetn]]
    connect_bd_net $design_aresetn [get_bd_pins $mrmac/s_axi_aresetn] [get_bd_pins $gt_quad_base/apb3presetn]

    # TX
    # combine the MRMAC stream ports
    set axis_tx [get_bd_intf_pins /network/AXIS_TX_${name}]
    set axis_tx_reg [tapasco::ip::create_axis_reg_slice axis_tx_reg]
    set_property -dict [list CONFIG.TDATA_NUM_BYTES.VALUE_SRC USER CONFIG.HAS_TKEEP.VALUE_SRC USER CONFIG.HAS_TLAST.VALUE_SRC USER] $axis_tx_reg
    # REG_CONFIG = bypass -> no logic involved; 32 bytes = 256 bit
    set_property -dict [list CONFIG.TDATA_NUM_BYTES $bytewidth CONFIG.REG_CONFIG {0} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1}] $axis_tx_reg
    connect_bd_intf_net $axis_tx [get_bd_intf_pins $axis_tx_reg/S_AXIS]
    connect_bd_net [get_bd_pins $mrmac/tx_axis_tlast_0] [get_bd_pins $axis_tx_reg/m_axis_tlast]
    connect_bd_net [get_bd_pins $mrmac/tx_axis_tready_0] [get_bd_pins $axis_tx_reg/m_axis_tready]
    connect_bd_net [get_bd_pins $mrmac/tx_axis_tvalid_0] [get_bd_pins $axis_tx_reg/m_axis_tvalid]
    # 256/384 bit tdata
    set tx_data_slice0 [tapasco::ip::create_xlslice tx_data_slice0 $bitwidth 0]
    set tx_data_slice1 [tapasco::ip::create_xlslice tx_data_slice1 $bitwidth 0]
    set tx_data_slice2 [tapasco::ip::create_xlslice tx_data_slice2 $bitwidth 0]
    set tx_data_slice3 [tapasco::ip::create_xlslice tx_data_slice3 $bitwidth 0]
    set_property -dict [list CONFIG.DIN_FROM  {63} CONFIG.DIN_TO   {0} CONFIG.DIN_WIDTH $bitwidth CONFIG.DOUT_WIDTH {64}] $tx_data_slice0
    set_property -dict [list CONFIG.DIN_FROM {127} CONFIG.DIN_TO  {64} CONFIG.DIN_WIDTH $bitwidth CONFIG.DOUT_WIDTH {64}] $tx_data_slice1
    set_property -dict [list CONFIG.DIN_FROM {191} CONFIG.DIN_TO {128} CONFIG.DIN_WIDTH $bitwidth CONFIG.DOUT_WIDTH {64}] $tx_data_slice2
    set_property -dict [list CONFIG.DIN_FROM {255} CONFIG.DIN_TO {192} CONFIG.DIN_WIDTH $bitwidth CONFIG.DOUT_WIDTH {64}] $tx_data_slice3
    connect_bd_net [get_bd_pins $axis_tx_reg/m_axis_tdata] [get_bd_pins $tx_data_slice0/Din] [get_bd_pins $tx_data_slice1/Din] [get_bd_pins $tx_data_slice2/Din] [get_bd_pins $tx_data_slice3/Din]
    connect_bd_net [get_bd_pins $tx_data_slice0/Dout] [get_bd_pins $mrmac/tx_axis_tdata0]
    connect_bd_net [get_bd_pins $tx_data_slice1/Dout] [get_bd_pins $mrmac/tx_axis_tdata1]
    connect_bd_net [get_bd_pins $tx_data_slice2/Dout] [get_bd_pins $mrmac/tx_axis_tdata2]
    connect_bd_net [get_bd_pins $tx_data_slice3/Dout] [get_bd_pins $mrmac/tx_axis_tdata3]
    if {$bitwidth > 256} {
        set tx_data_slice4 [tapasco::ip::create_xlslice tx_data_slice4 $bitwidth 0]
        set tx_data_slice5 [tapasco::ip::create_xlslice tx_data_slice5 $bitwidth 0]
        set_property -dict [list CONFIG.DIN_FROM {319} CONFIG.DIN_TO {256} CONFIG.DIN_WIDTH $bitwidth CONFIG.DOUT_WIDTH {64}] $tx_data_slice4
        set_property -dict [list CONFIG.DIN_FROM {383} CONFIG.DIN_TO {320} CONFIG.DIN_WIDTH $bitwidth CONFIG.DOUT_WIDTH {64}] $tx_data_slice5
        connect_bd_net [get_bd_pins $axis_tx_reg/m_axis_tdata] [get_bd_pins $tx_data_slice4/Din] [get_bd_pins $tx_data_slice5/Din]
        connect_bd_net [get_bd_pins $tx_data_slice4/Dout] [get_bd_pins $mrmac/tx_axis_tdata4]
        connect_bd_net [get_bd_pins $tx_data_slice5/Dout] [get_bd_pins $mrmac/tx_axis_tdata5]
    }
    # 32/48 bit tkeep
    set tx_keep_slice0 [tapasco::ip::create_xlslice tx_keep_slice0 $bytewidth 0]
    set tx_keep_slice1 [tapasco::ip::create_xlslice tx_keep_slice1 $bytewidth 0]
    set tx_keep_slice2 [tapasco::ip::create_xlslice tx_keep_slice2 $bytewidth 0]
    set tx_keep_slice3 [tapasco::ip::create_xlslice tx_keep_slice3 $bytewidth 0]
    set_property -dict [list CONFIG.DIN_FROM  {7} CONFIG.DIN_TO  {0} CONFIG.DIN_WIDTH $bytewidth CONFIG.DOUT_WIDTH {8}] $tx_keep_slice0
    set_property -dict [list CONFIG.DIN_FROM {15} CONFIG.DIN_TO  {8} CONFIG.DIN_WIDTH $bytewidth CONFIG.DOUT_WIDTH {8}] $tx_keep_slice1
    set_property -dict [list CONFIG.DIN_FROM {23} CONFIG.DIN_TO {16} CONFIG.DIN_WIDTH $bytewidth CONFIG.DOUT_WIDTH {8}] $tx_keep_slice2
    set_property -dict [list CONFIG.DIN_FROM {31} CONFIG.DIN_TO {24} CONFIG.DIN_WIDTH $bytewidth CONFIG.DOUT_WIDTH {8}] $tx_keep_slice3
    connect_bd_net [get_bd_pins $axis_tx_reg/m_axis_tkeep] [get_bd_pins $tx_keep_slice0/Din] [get_bd_pins $tx_keep_slice1/Din] [get_bd_pins $tx_keep_slice2/Din] [get_bd_pins $tx_keep_slice3/Din]
    connect_bd_net [get_bd_pins $tx_keep_slice1/Dout] [get_bd_pins $mrmac/tx_axis_tkeep_user1]
    connect_bd_net [get_bd_pins $tx_keep_slice2/Dout] [get_bd_pins $mrmac/tx_axis_tkeep_user2]
    connect_bd_net [get_bd_pins $tx_keep_slice3/Dout] [get_bd_pins $mrmac/tx_axis_tkeep_user3]
    if {$bitwidth > 256} {
        set tx_keep_slice4 [tapasco::ip::create_xlslice tx_keep_slice4 $bytewidth 0]
        set tx_keep_slice5 [tapasco::ip::create_xlslice tx_keep_slice5 $bytewidth 0]
        set_property -dict [list CONFIG.DIN_FROM {39} CONFIG.DIN_TO {32} CONFIG.DIN_WIDTH $bytewidth CONFIG.DOUT_WIDTH {8}] $tx_keep_slice4
        set_property -dict [list CONFIG.DIN_FROM {47} CONFIG.DIN_TO {40} CONFIG.DIN_WIDTH $bytewidth CONFIG.DOUT_WIDTH {8}] $tx_keep_slice5
        connect_bd_net [get_bd_pins $axis_tx_reg/m_axis_tkeep] [get_bd_pins $tx_keep_slice4/Din] [get_bd_pins $tx_keep_slice5/Din]
        connect_bd_net [get_bd_pins $tx_keep_slice4/Dout] [get_bd_pins $mrmac/tx_axis_tkeep_user4]
        connect_bd_net [get_bd_pins $tx_keep_slice5/Dout] [get_bd_pins $mrmac/tx_axis_tkeep_user5]
    }
    # set keep[8:10] to 0
    set tx_keep_concat0 [tapasco::ip::create_xlconcat tx_keep_concat0 2]
    set_property -dict [list CONFIG.IN1_WIDTH.VALUE_SRC USER CONFIG.IN0_WIDTH.VALUE_SRC USER] $tx_keep_concat0
    set_property -dict [list CONFIG.NUM_PORTS {2} CONFIG.IN0_WIDTH {8} CONFIG.IN1_WIDTH {3}] $tx_keep_concat0
    connect_bd_net [get_bd_pins $tx_keep_slice0/Dout] [get_bd_pins $tx_keep_concat0/In0]
    connect_bd_net [get_bd_pins $tx_keep_concat0/dout] [get_bd_pins $mrmac/tx_axis_tkeep_user0]
    # RX
    # combine the MRMAC stream ports
    set axis_rx [get_bd_intf_pins /network/AXIS_RX_${name}]
    set axis_rx_reg [tapasco::ip::create_axis_reg_slice axis_rx_reg]
    set_property -dict [list CONFIG.TDATA_NUM_BYTES.VALUE_SRC USER CONFIG.HAS_TKEEP.VALUE_SRC USER CONFIG.HAS_TLAST.VALUE_SRC USER CONFIG.HAS_TREADY.VALUE_SRC USER] $axis_rx_reg
    # REG_CONFIG = bypass -> no logic involved; 32 bytes = 256 bit
    # no ready signal
    set_property -dict [list CONFIG.TDATA_NUM_BYTES $bytewidth CONFIG.REG_CONFIG {0} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.HAS_TREADY {0}] $axis_rx_reg
    connect_bd_intf_net $axis_rx [get_bd_intf_pins $axis_rx_reg/M_AXIS]
    connect_bd_net [get_bd_pins $mrmac/rx_axis_tlast_0] [get_bd_pins $axis_rx_reg/s_axis_tlast]
    connect_bd_net [get_bd_pins $mrmac/rx_axis_tvalid_0] [get_bd_pins $axis_rx_reg/s_axis_tvalid]
    # 256/384 bit tdata
    set rx_port_count 4
    if {$bitwidth > 256} {
        set rx_port_count 6
    }
    set rx_data_concat [tapasco::ip::create_xlconcat rx_data_concat $rx_port_count]
    set_property -dict [list CONFIG.IN3_WIDTH.VALUE_SRC USER CONFIG.IN2_WIDTH.VALUE_SRC USER CONFIG.IN1_WIDTH.VALUE_SRC USER CONFIG.IN0_WIDTH.VALUE_SRC USER] $rx_data_concat
    set_property -dict [list CONFIG.NUM_PORTS $rx_port_count CONFIG.IN0_WIDTH {64} CONFIG.IN1_WIDTH {64} CONFIG.IN2_WIDTH {64} CONFIG.IN3_WIDTH {64} CONFIG.IN4_WIDTH {64} CONFIG.IN5_WIDTH {64}] $rx_data_concat
    connect_bd_net [get_bd_pins $axis_rx_reg/s_axis_tdata] [get_bd_pins $rx_data_concat/dout]
    connect_bd_net [get_bd_pins $rx_data_concat/In0] [get_bd_pins $mrmac/rx_axis_tdata0]
    connect_bd_net [get_bd_pins $rx_data_concat/In1] [get_bd_pins $mrmac/rx_axis_tdata1]
    connect_bd_net [get_bd_pins $rx_data_concat/In2] [get_bd_pins $mrmac/rx_axis_tdata2]
    connect_bd_net [get_bd_pins $rx_data_concat/In3] [get_bd_pins $mrmac/rx_axis_tdata3]
    if {$bitwidth > 256} {
        connect_bd_net [get_bd_pins $rx_data_concat/In4] [get_bd_pins $mrmac/rx_axis_tdata4]
        connect_bd_net [get_bd_pins $rx_data_concat/In5] [get_bd_pins $mrmac/rx_axis_tdata5]
    }
    # 32/48 bit tkeep
    set rx_keep_concat [tapasco::ip::create_xlconcat rx_keep_concat $rx_port_count]
    set_property -dict [list CONFIG.IN3_WIDTH.VALUE_SRC USER CONFIG.IN2_WIDTH.VALUE_SRC USER CONFIG.IN1_WIDTH.VALUE_SRC USER CONFIG.IN0_WIDTH.VALUE_SRC USER] $rx_keep_concat
    set_property -dict [list CONFIG.NUM_PORTS $rx_port_count CONFIG.IN0_WIDTH {8} CONFIG.IN1_WIDTH {8} CONFIG.IN2_WIDTH {8} CONFIG.IN3_WIDTH {8} CONFIG.IN4_WIDTH {8} CONFIG.IN5_WIDTH {8}] $rx_keep_concat
    connect_bd_net [get_bd_pins $axis_rx_reg/s_axis_tkeep] [get_bd_pins $rx_keep_concat/dout]
    connect_bd_net [get_bd_pins $rx_keep_concat/In0] [get_bd_pins $mrmac/rx_axis_tkeep_user0]
    connect_bd_net [get_bd_pins $rx_keep_concat/In1] [get_bd_pins $mrmac/rx_axis_tkeep_user1]
    connect_bd_net [get_bd_pins $rx_keep_concat/In2] [get_bd_pins $mrmac/rx_axis_tkeep_user2]
    connect_bd_net [get_bd_pins $rx_keep_concat/In3] [get_bd_pins $mrmac/rx_axis_tkeep_user3]
    if {$bitwidth > 256} {
        connect_bd_net [get_bd_pins $rx_keep_concat/In4] [get_bd_pins $mrmac/rx_axis_tkeep_user4]
        connect_bd_net [get_bd_pins $rx_keep_concat/In5] [get_bd_pins $mrmac/rx_axis_tkeep_user5]
    }

    connect_bd_net $user_clk [get_bd_pins $axis_rx_reg/aclk] [get_bd_pins $axis_tx_reg/aclk] \
        [get_bd_pins /network/sfp_tx_clock_${name}]
    connect_bd_net [get_bd_pins $mrmac/gt_rx_reset_done_out] [get_bd_pins $axis_tx_reg/aresetn] [get_bd_pins $axis_rx_reg/aresetn] \
        [get_bd_pins /network/sfp_rx_resetn_${name}]
    current_bd_instance $old_bd
    # workaround: connecting two pins out of the hierarchical block cell does not work, so connect the second clock and reset directly on lower hierarchy level
    connect_bd_net [get_bd_pins /network/sfp_tx_clock_${name}] [get_bd_pins /network/sfp_rx_clock_${name}]
    connect_bd_net [get_bd_pins /network/sfp_rx_resetn_${name}] [get_bd_pins /network/sfp_tx_resetn_${name}]
  }
  }
}
