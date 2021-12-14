# Copyright (c) 2014-2021 Embedded Systems and Applications, TU Darmstadt.
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

namespace eval svm {
  proc add_iommu {} {
    if {[tapasco::is_feature_enabled "SVM"]} {

      # add slave port to host subsystem
      current_bd_instance "/host"
      set m_mmu [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_MMU"]
      set num_mi_out_old [get_property CONFIG.NUM_MI [get_bd_cells out_ic]]
      set num_mi_out [expr "$num_mi_out_old + 1"]
      set_property -dict [list CONFIG.NUM_MI $num_mi_out] [get_bd_cells out_ic]
      connect_bd_intf_net [get_bd_intf_pins out_ic/[format "M%02d_AXI" $num_mi_out_old]] $m_mmu

      # remove BlueDMA and insert PageDMA core
      current_bd_instance "/memory"
      delete_bd_objs [get_bd_nets dma_IRQ_write] [get_bd_nets dma_IRQ_read] [get_bd_intf_nets S_DMA_1] [get_bd_intf_nets dma_m32_axi] [get_bd_intf_nets dma_m64_axi] [get_bd_cells dma]

      set pcie_aclk [tapasco::subsystem::get_port "host" "clk"]
      set pcie_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
      set design_aclk [tapasco::subsystem::get_port "design" "clk"]

      set page_dma [tapasco::ip::create_page_dma dma_0]
      set mig_ic [get_bd_cells mig_ic]
      connect_bd_net $pcie_aclk [get_bd_pins $page_dma/aclk]
      connect_bd_net $pcie_p_aresetn [get_bd_pins $page_dma/resetn]
      connect_bd_net [get_bd_pins $page_dma/intr_c2h] [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_READ]
      connect_bd_net [get_bd_pins $page_dma/intr_h2c] [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_WRITE]
      connect_bd_intf_net [get_bd_intf_pins S_DMA] [get_bd_intf_pins $page_dma/S_AXI_CTRL]
      connect_bd_intf_net [get_bd_intf_pins $page_dma/M_AXI_MEM] [get_bd_intf_pins $mig_ic/S00_AXI]
      connect_bd_intf_net [get_bd_intf_pins $page_dma/M_AXI_PCI] [get_bd_intf_pins M_HOST]

      # add MMU to memory subsystem
      current_bd_instance "/memory"

      set s_mmu [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MMU"]
      set mmu [tapasco::ip::create_tapasco_mmu mmu_0]
      set mmu_sc [tapasco::ip::create_axi_sc "mmu_sc" 1 1 2]

      connect_bd_net $pcie_aclk [get_bd_pins $mmu/aclk]
      connect_bd_net $pcie_p_aresetn [get_bd_pins $mmu/resetn]
      connect_bd_net $pcie_aclk [get_bd_pins $mmu_sc/aclk]
      connect_bd_net $design_aclk [get_bd_pins $mmu_sc/aclk1]

      delete_bd_objs [get_bd_intf_nets "S_MEM_0_1"]
      connect_bd_intf_net [get_bd_intf_pins S_MMU] [get_bd_intf_pins $mmu/S_AXI_CTRL]

      # FIXME put Smartconnect between target IPs and MMU to perform clock convertion for now
      # can be left out as soon as we switch from Interconnects to Smartconnects in the interconnect tree
      connect_bd_intf_net [get_bd_intf_pins S_MEM_0] [get_bd_intf_pins $mmu_sc/S00_AXI]
      connect_bd_intf_net [get_bd_intf_pins $mmu_sc/M00_AXI] [get_bd_intf_pins $mmu/S_AXI_ACC]
      connect_bd_intf_net [get_bd_intf_pins $mmu/M_AXI_MEM] [get_bd_intf_pins mig_ic/S01_AXI]

      connect_bd_net [get_bd_pins $mmu/pgf_intr] [tapasco::ip::add_interrupt "PLATFORM_COMPONENT_MMU_FAULT" "host"]

      current_bd_instance
      save_bd_design
    }
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "SVM"]} {
      set args [lappend args "M_MMU" [list 0x50000 0x10000 0 "PLATFORM_COMPONENT_MMU"]]
      return $args
    }
  }
}

tapasco::register_plugin "platform::svm::add_iommu" "pre-wiring"
tapasco::register_plugin "platform::svm::addressmap" "post-address-map"
