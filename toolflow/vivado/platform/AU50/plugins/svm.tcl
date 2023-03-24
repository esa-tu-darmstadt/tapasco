# Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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

# If SVM is in use we only use two HBM port (DMA and MMU)
if {[tapasco::is_feature_enabled "SVM"]} {
  proc get_ignored_segments {} {
    set ignored [list]
    for {set i 0} {$i < 32} {incr i} {
      set mem_index [format %02s $i]
      lappend ignored "/memory/hbm_0/SAXI_00/HBM_MEM${mem_index}"
      lappend ignored "/memory/hbm_0/SAXI_31/HBM_MEM${mem_index}"
    }
    return $ignored
  }

  proc set_addressmap_AU50 {{args {}}} {
    set num_masters [llength [::arch::get_masters]]
    for {set i 0} {$i < 32} {incr i} {
      set mem_index [format %02s $i]
      assign_bd_address [get_bd_addr_segs memory/hbm_0/SAXI_00/HBM_MEM${mem_index}]
      assign_bd_address [get_bd_addr_segs memory/hbm_0/SAXI_31/HBM_MEM${mem_index}]
    }
    for {set i 1} {$i < $num_masters} {incr i} {
      set name "M_MEM_$i"
      set args [lappend args $name [list 0 0 0 ""]]
    }
    return $args
  }
}

namespace eval svm {
  proc is_svm_supported {} {
    return true
  }

  # TODO implement network migrations
  proc is_network_port_valid {port_no} {
    return false
  }

  proc add_iommu {args} {
    if {[tapasco::is_feature_enabled "SVM"]} {
      set old_instance [current_bd_instance .]

      # add slave port to host subsystem
      current_bd_instance "/host"
      set m_mmu [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_MMU"]
      set num_mi_out_old [get_property CONFIG.NUM_MI [get_bd_cells out_ic]]
      set num_mi_out [expr "$num_mi_out_old + 1"]
      set_property -dict [list CONFIG.NUM_MI $num_mi_out] [get_bd_cells out_ic]
      connect_bd_intf_net [get_bd_intf_pins out_ic/[format "M%02d_AXI" $num_mi_out_old]] $m_mmu

      # remove BlueDMA and insert PageDMA core
      current_bd_instance "/memory"

      set pcie_aclk [tapasco::subsystem::get_port "host" "clk"]
      set pcie_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
      set design_aclk [tapasco::subsystem::get_port "design" "clk"]
      set memory_aclk [tapasco::subsystem::get_port "mem" "clk"]
      set hbm_clk [get_bd_pins memory_clk_wiz/hbm_clk]
      set hbm_aresetn [get_bd_pins hbm_rst_gen/peripheral_aresetn]
      set mig_ic [get_bd_cells mig_ic]
      set hbm [get_bd_cells hbm_0]

      delete_bd_objs [get_bd_nets dma_IRQ_write] [get_bd_nets dma_IRQ_read] [get_bd_intf_nets S_DMA_1] [get_bd_intf_nets dma_m32_axi] [get_bd_intf_nets dma_m64_axi] [get_bd_cells dma]
      disconnect_bd_net /memory/memory_clk_wiz_memory_clk [get_bd_pins $mig_ic/aclk]
      disconnect_bd_net /memory/design_clk_1 [get_bd_pins hbm_0/AXI_00_ACLK]
      disconnect_bd_net /memory/design_peripheral_aresetn_1 [get_bd_pins hbm_0/AXI_00_ARESET_N]

      # TODO insert NetworkPageDMA if necessary
      set page_dma [tapasco::ip::create_page_dma dma_0]
      connect_bd_net $pcie_aclk [get_bd_pins $page_dma/aclk]
      connect_bd_net $pcie_p_aresetn [get_bd_pins $page_dma/resetn]
      connect_bd_net [get_bd_pins $page_dma/intr_c2h] [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_READ]
      connect_bd_net [get_bd_pins $page_dma/intr_h2c] [get_bd_pins intr_PLATFORM_COMPONENT_DMA0_WRITE]
      connect_bd_intf_net [get_bd_intf_pins S_DMA] [get_bd_intf_pins $page_dma/S_AXI_CTRL]
      connect_bd_intf_net [get_bd_intf_pins $page_dma/M_AXI_MEM] [get_bd_intf_pins $mig_ic/S00_AXI]
      connect_bd_intf_net [get_bd_intf_pins $page_dma/M_AXI_PCI] [get_bd_intf_pins M_HOST]

save_bd_design

      # create smartconnect tree in case of multiple master ports
      set num_masters [llength [::arch::get_masters]]
      for {set i 0} {$i < $num_masters} {incr i} {
        delete_bd_objs [get_bd_intf_nets "S_MEM_${i}_1"]
      }
      set sc_tree [tapasco::create_smartconnect_tree "mmu_sc_tree" $num_masters]


      # disable unused HBM ports
      if {$num_masters > 1} {
        set hbm_config [list]
        for {set i 1} {$i < $num_masters && $i < 31} {incr i} {
          lappend hbm_config CONFIG.USER_SAXI_[format %02s $i] {false}
        }
        set_property -dict $hbm_config $hbm
      }

      # add MMU to memory subsystem
      set s_mmu [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_MMU"]
      set mmu [tapasco::ip::create_tapasco_mmu mmu_0]
      set mmu_mem_sc [tapasco::ip::create_axi_sc "mmu_mem_sc" 1 1 2]

      connect_bd_net $pcie_aclk [get_bd_pins $mmu/aclk]
      connect_bd_net $pcie_p_aresetn [get_bd_pins $mmu/resetn]
      connect_bd_net $pcie_aclk [get_bd_pins $sc_tree/m_aclk]
      connect_bd_net $design_aclk [get_bd_pins $sc_tree/s_aclk]
      connect_bd_net $pcie_aclk [get_bd_pins $mmu_mem_sc/aclk]
      connect_bd_net $hbm_clk [get_bd_pins $mmu_mem_sc/aclk1]
      connect_bd_net $pcie_aclk [get_bd_pins $mig_ic/aclk]
      connect_bd_net $hbm_clk [get_bd_pins $hbm/AXI_00_ACLK]
      connect_bd_net $hbm_aresetn [get_bd_pins $hbm/AXI_00_ARESET_N]

      # create AXI connections
      for {set i 0} {$i < $num_masters} {incr i} {
        connect_bd_intf_net [get_bd_intf_pins S_MEM_$i] [get_bd_intf_pins $sc_tree/[format "S%03s_AXI" $i]]
      }
      connect_bd_intf_net [get_bd_intf_pins S_MMU] [get_bd_intf_pins $mmu/S_AXI_CTRL]
      connect_bd_intf_net [get_bd_intf_pins $sc_tree/M000_AXI] [get_bd_intf_pins $mmu/S_AXI_ACC]
      connect_bd_intf_net [get_bd_intf_pins $mmu/M_AXI_MEM] [get_bd_intf_pins $mmu_mem_sc/S00_AXI]
      connect_bd_intf_net [get_bd_intf_pins $mmu_mem_sc/M00_AXI] [get_bd_intf_pins $hbm/SAXI_00]

      # connect page fault interrupt
      connect_bd_net [get_bd_pins $mmu/pgf_intr] [tapasco::ip::add_interrupt "PLATFORM_COMPONENT_MMU_FAULT" "host"]

      current_bd_instance $old_instance
    }
    return $args
  }
}
