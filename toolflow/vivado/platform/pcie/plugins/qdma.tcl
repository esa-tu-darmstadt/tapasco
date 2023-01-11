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

namespace eval qdma {

  # Overwrite this function with true if platform supports QDMA
  proc is_qdma_supported {} {
    return false
  }

  # substitute standard MSIX-controller with special QDMA interrupt controller
  proc substitute_intr_ctrl {} {
    puts "Removing interrupt controller..."
    current_bd_instance "/intc"

    # delete standard interrupt controller
    delete_bd_objs [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_READ] \
      [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_WRITE] \
      [get_bd_intf_pins M_MSIX]
    delete_bd_objs [get_bd_nets design_clk_1] \
      [get_bd_nets design_peripheral_aresetn_1] \
      [get_bd_nets host_clk_1] \
      [get_bd_nets host_peripheral_aresetn_1] \
      [get_bd_nets int_cc_host_dout]

    if {[llength [get_bd_cells int_cc_design_merge]] > 0} {
      delete_bd_objs [get_bd_nets int_cc_design_merge_dout]
    } else {
      delete_bd_objs [get_bd_nets int_cc_design_0_dout]
    }

    delete_bd_objs [get_bd_intf_nets S_INTC_1] \
      [get_bd_intf_nets msix_intr_ctrl_msix] \
      [get_bd_cells msix_intr_ctrl]

    delete_bd_objs [get_bd_nets intr_PLATFORM_COMPONENT_DMA0_READ_1] \
      [get_bd_nets intr_PLATFORM_COMPONENT_DMA0_WRITE_1] \
      [get_bd_cells int_cc_host]

    # add new ports
    set usr_irq [create_bd_intf_pin -mode Master -vlnv xilinx.com:display_eqdma:usr_irq_rtl:1.0 "usr_irq"]
    set aclk [tapasco::subsystem::get_port "host" "clk"]
    set p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    # add new interupt controller
    set qdma_intr_ctrl [tapasco::ip::create_qdma_intr_ctrl "qdma_intr_ctrl"]

    # connect everything
    connect_bd_net $aclk [get_bd_pins $qdma_intr_ctrl/S_AXI_aclk]
    connect_bd_net $design_aclk [get_bd_pins $qdma_intr_ctrl/design_clk]
    connect_bd_net $p_aresetn [get_bd_pins $qdma_intr_ctrl/S_AXI_aresetn]
    connect_bd_net $design_aresetn [get_bd_pins $qdma_intr_ctrl/design_rst]

    connect_bd_intf_net [get_bd_intf_pins S_INTC] [get_bd_intf_pins $qdma_intr_ctrl/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins $qdma_intr_ctrl/usr_irq] $usr_irq
    if {[llength [get_bd_cells int_cc_design_merge]] > 0} {
      connect_bd_net [get_bd_pins int_cc_design_merge/dout] [get_bd_pins $qdma_intr_ctrl/interrupt_design]
    } else {
      connect_bd_net [get_bd_pins int_cc_design_0/dout] [get_bd_pins $qdma_intr_ctrl/interrupt_design]
    }

    current_bd_instance
  }

  proc remove_dma_engine {} {
    puts "Removing BlueDMA engine..."
    current_bd_instance "/memory"
    delete_bd_objs [get_bd_intf_nets S_DMA_1] \
      [get_bd_intf_pins S_DMA] \
      [get_bd_intf_pins M_HOST] \
      [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_WRITE] \
      [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_READ]
    delete_bd_objs [get_bd_intf_nets S_DMA_1] \
      [get_bd_intf_nets dma_m32_axi] \
      [get_bd_intf_nets dma_m64_axi] \
      [get_bd_nets host_peripheral_aresetn_1] \
      [get_bd_nets dma_IRQ_write] \
      [get_bd_nets dma_IRQ_read] \
      [get_bd_cells dma]

    # rename port to avoid naming conflicts in address map
    set s_mem_qdma [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MEM_QDMA"]
    connect_bd_intf_net $s_mem_qdma [get_bd_intf_pins mig_ic/S00_AXI]

    current_bd_instance
  }

  proc remove_pcie_block {} {
    puts "Removing PCIe block..."
    delete_bd_objs [get_bd_nets /pcie_perstn_1] \
      [get_bd_ports /pcie_perstn] \
      [get_bd_intf_nets /pcie_refclk_1] \
      [get_bd_intf_nets /host_pci_express_x16] \
      [get_bd_intf_ports /pcie_refclk] \
      [get_bd_intf_ports /pci_express_x16]
    delete_bd_objs [get_bd_intf_nets Conn2] \
      [get_bd_intf_nets Conn1] \
      [get_bd_intf_pins pcie_refclk] \
      [get_bd_intf_pins pci_express_x16] \
      [get_bd_nets pcie_perstn_1] \
      [get_bd_pins pcie_perstn] \
      [get_bd_intf_nets S_HOST_1] \
      [get_bd_intf_pins S_HOST] \
      [get_bd_intf_nets S_MSIX_1] \
      [get_bd_intf_pins S_MSIX]
    delete_bd_objs [get_bd_nets MSIxTranslator_m_cfg_interrupt_msix_address] \
      [get_bd_nets MSIxTranslator_m_cfg_interrupt_msix_data] \
      [get_bd_nets MSIxTranslator_m_cfg_interrupt_msix_int] \
      [get_bd_nets axi_pcie3_0_cfg_interrupt_msix_enable] \
      [get_bd_nets axi_pcie3_0_cfg_interrupt_msi_fail] \
      [get_bd_nets axi_pcie3_0_cfg_interrupt_msi_sent] \
      [get_bd_cells MSIxTranslator]
    delete_bd_objs [get_bd_nets util_ds_buf_IBUF_DS_ODIV2] \
      [get_bd_nets util_ds_buf_IBUF_OUT] \
      [get_bd_cells util_ds_buf]
    delete_bd_objs [get_bd_nets axi_pcie3_0_axi_aclk] \
      [get_bd_nets axi_pcie3_0_axi_aresetn] \
      [get_bd_intf_nets in_ic_M00_AXI] \
      [get_bd_intf_nets axi_pcie3_0_M_AXI_B] \
      [get_bd_cells axi_pcie3_0]
  }

  # works for QDMA 4.0, overwrite for QDMA 3.0
  proc add_qdma_block {} {
    puts "Adding QDMA block..."
    set qdma [tapasco::ip::create_qdma qdma_0]

      apply_bd_automation -rule xilinx.com:bd_rule:qdma -config { axi_clk {Maximum Data Width} axi_intf {AXI_MM} bar_size {Disable} lane_width {X16} link_speed {8.0 GT/s (PCIe Gen 3)}}  [get_bd_cells $qdma]

      set_property -dict [list CONFIG.axist_bypass_en {true} \
        CONFIG.dsc_byp_mode {Descriptor_bypass_and_internal} \
        CONFIG.pf0_bar0_type_qdma {AXI_Bridge_Master} \
        CONFIG.pf0_bar0_scale_qdma {Megabytes} \
        CONFIG.pf0_bar0_size_qdma {64} \
        CONFIG.pf0_bar2_type_qdma {DMA} \
        CONFIG.pf0_bar2_size_qdma {256} \
        CONFIG.pf1_bar0_type_qdma {AXI_Bridge_Master} \
        CONFIG.pf1_bar0_scale_qdma {Megabytes} \
        CONFIG.pf1_bar0_size_qdma {64} \
        CONFIG.pf1_bar2_type_qdma {DMA} \
        CONFIG.pf1_bar2_size_qdma {256} \
        CONFIG.pf2_bar0_type_qdma {AXI_Bridge_Master} \
        CONFIG.pf2_bar0_scale_qdma {Megabytes} \
        CONFIG.pf2_bar0_size_qdma {64} \
        CONFIG.pf2_bar2_type_qdma {DMA} \
        CONFIG.pf2_bar2_size_qdma {256} \
        CONFIG.pf3_bar0_type_qdma {AXI_Bridge_Master} \
        CONFIG.pf3_bar0_scale_qdma {Megabytes} \
        CONFIG.pf3_bar0_size_qdma {64} \
        CONFIG.pf3_bar2_type_qdma {DMA} \
        CONFIG.pf3_bar2_size_qdma {256} \
        CONFIG.csr_axilite_slave {false} \
        CONFIG.en_bridge_slv {true} \
        CONFIG.axibar_notranslate {true} \
        CONFIG.vdm_en {1} \
        CONFIG.pf0_device_id {7038} \
        CONFIG.PF0_MSIX_CAP_TABLE_SIZE_qdma {01F} \
        CONFIG.PF0_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
        CONFIG.PF1_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
        CONFIG.PF2_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
        CONFIG.PF3_MSIX_CAP_TABLE_BIR_qdma {BAR_3:2} \
        CONFIG.PF0_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
        CONFIG.PF1_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
        CONFIG.PF2_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
        CONFIG.PF3_MSIX_CAP_PBA_BIR_qdma {BAR_3:2} \
        CONFIG.adv_int_usr {true} \
        CONFIG.en_pcie_drp {true}] $qdma
      return $qdma
  }

  proc substitute_pcie_block {} {
    current_bd_instance "/host"
    remove_pcie_block

    # create hierarchical ports
    set m_mem_qdma [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_MEM_QDMA"]
    set s_desc_gen [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DMA"]
    set usr_irq [create_bd_intf_pin -mode Slave -vlnv xilinx.com:display_eqdma:usr_irq_rtl:1.0 "usr_irq"]

    set pcie_aclk_in [tapasco::subsystem::get_port "host" "clk"]
    set pcie_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]

    # add QDMA and custom configuration cores
    set qdma [add_qdma_block]
    set qdma_conf [tapasco::ip::create_qdma_configurator qdma_conf_0]
    set desc_gen [tapasco::ip::create_qdma_desc_gen desc_gen_0]
    set dummy_master [tapasco::ip::create_axi_dummy_master "dummy_master"]

    set out_ic [get_bd_cells out_ic]
    set in_ic [get_bd_cells in_ic]

    # connect clock and reset signals
    connect_bd_net $pcie_aclk_in [get_bd_pins $desc_gen/aclk] \
      [get_bd_pins $qdma_conf/clk] [get_bd_pins $qdma/drp_clk] \
      [get_bd_pins $dummy_master/M_AXI_aclk]
    connect_bd_net $pcie_p_aresetn [get_bd_pins $desc_gen/resetn] \
      [get_bd_pins $qdma_conf/resetn] \
      [get_bd_pins $dummy_master/M_AXI_aresetn]

    connect_bd_net [get_bd_pins $qdma/axi_aclk] [get_bd_pins pcie_aclk]
    connect_bd_net [get_bd_pins $qdma/axi_aresetn] [get_bd_pins pcie_aresetn]

    # create AXI connections
    connect_bd_intf_net [get_bd_intf_pins $qdma/M_AXI_BRIDGE] \
        [get_bd_intf_pins -of_objects $out_ic -filter "VLNV == [tapasco::ip::get_vlnv aximm_intf] && MODE == Slave"]
    connect_bd_intf_net [get_bd_intf_pins $qdma/M_AXI] $m_mem_qdma
    connect_bd_intf_net [get_bd_intf_pins $dummy_master/M_AXI] [get_bd_intf_pins $in_ic/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins -of_object $in_ic -filter { MODE == Master }] \
      [get_bd_intf_pins $qdma/S_AXI_BRIDGE]
    connect_bd_intf_net $s_desc_gen [get_bd_intf_pins $desc_gen/S_AXI_CTRL]

    # connect remaining pins
    connect_bd_intf_net [get_bd_intf_pins $qdma_conf/drp] [get_bd_intf_pins $qdma/drp]
    connect_bd_intf_net [get_bd_intf_pins $qdma_conf/msix_vector_ctrl] [get_bd_intf_pins $qdma/msix_vector_ctrl]
    connect_bd_net [get_bd_pins $qdma_conf/dma_resetn] [get_bd_pins $qdma/soft_reset_n]
    connect_bd_net [get_bd_pins $desc_gen/trigger_reset_cycle] [get_bd_pins $qdma_conf/start_reset]
    connect_bd_intf_net [get_bd_intf_pins $desc_gen/c2h_byp_in] [get_bd_intf_pins $qdma/c2h_byp_in_mm]
    connect_bd_intf_net [get_bd_intf_pins $desc_gen/h2c_byp_in] [get_bd_intf_pins $qdma/h2c_byp_in_mm]
    connect_bd_intf_net [get_bd_intf_pins $qdma/tm_dsc_sts] [get_bd_intf_pins $desc_gen/tm_dsc_sts]
    connect_bd_intf_net [get_bd_intf_pins $qdma/qsts_out] [get_bd_intf_pins $desc_gen/qsts_out]
    connect_bd_intf_net [get_bd_intf_pins $qdma/c2h_byp_out] [get_bd_intf_pins $desc_gen/c2h_byp_out]
    connect_bd_intf_net [get_bd_intf_pins $qdma/h2c_byp_out] [get_bd_intf_pins $desc_gen/h2c_byp_out]
    connect_bd_intf_net $usr_irq [get_bd_intf_pins $qdma/usr_irq]

    current_bd_instance
  }

  # main function of feature calling subfunctions after each other
  proc qdma_feature_top {} {
    if {[tapasco::is_feature_enabled "QDMA"]} {
      if {[is_qdma_supported]} {
        substitute_intr_ctrl
        remove_dma_engine
        substitute_pcie_block
      } else {
        puts "ERROR: QDMA not supported by chosen platform..."
        exit 1
      }
    }
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "QDMA"]} {
      set args [lappend args "M_MEM_QDMA" [list 0 0 [expr "1 << 64"] ""]]
    }
    return $args
  }
}

tapasco::register_plugin "platform::qdma::qdma_feature_top" "pre-wiring"
tapasco::register_plugin "platform::qdma::addressmap" "post-address-map"
