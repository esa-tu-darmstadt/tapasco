# Copyright (c) 2014-2025 Embedded Systems and Applications, TU Darmstadt.
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

if {[tapasco::is_feature_enabled "NVME"]} {
  proc create_custom_subsystem_nvme {} {

    if {![nvme::is_nvme_supported]} {
      error "ERROR: NVME feature not suppoerted on specified platform"
    }

    set mem_opt [tapasco::get_feature_option "NVME" "memory" "none"]
    if {$mem_opt == "on-board-dram"} {
      puts "Use FPGA on-board DRAM for data transfer"
    } elseif {$mem_opt == "host-dram" } {
      puts "Use host DRAM for data transfer"
    } elseif {$mem_opt == "uram"} {
      puts "Use integrated URAM for data transfer"
    } else {
      error "ERROR: Invalid memory option for NVMe extension."
      exit 1
    }

    set pcie_aclk [tapasco::subsystem::get_port "host" "clk"]
    set pcie_p_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
    set pcie_ic_aresetn [tapasco::subsystem::get_port "host" "rst" "interconnect"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_resetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
    set design_ic_resetn [tapasco::subsystem::get_port "design" "rst" "interconnect"]
    set mem_aclk [tapasco::subsystem::get_port "mem" "clk"]
    set mem_resetn [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
    set mem_ic_resetn [tapasco::subsystem::get_port "mem" "rst" "interconnect"]

    set m_ssd [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_NVME_DOORBELL"]
    set s_nvme_queues [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_NVME_QUEUES"]
    set s_nvme_ctrl [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_NVME_CTRL"]
    set s_read_cmd [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 "S_NVME_RD_CMD"]
    set s_write_cmd [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 "S_NVME_WR_CMD"]
    set m_read_rsp [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 "M_NVME_RD_RSP"]
    set m_write_rsp [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 "M_NVME_WR_RSP"]
    if {$mem_opt == "uram" || $mem_opt == "on-board-dram"} {
      # connection is not used if we use data buffers in host memory
      set s_nvme_data [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_NVME_DATA"]
    }
    if {$mem_opt == "on-board-dram" || $mem_opt == "host-dram"} {
      set m_nvme_ddr [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_DDR_NVME"]
    }

    # create NVMeStreamer
    if {$mem_opt == "uram"} {
      set nvmestr [tapasco::ip::create_nvme_streamer_uram nvme_streamer_uram_0]
    } else {
      set nvmestr [tapasco::ip::create_nvme_streamer_dram nvme_streamer_dram_0]
      if {$mem_opt == "host-dram"} {
        set_property CONFIG.host_ddr 0x1 $nvmestr
      } else {
        set_property CONFIG.host_ddr 0x0 $nvmestr
      }
    }
    set ssd_base [tapasco::get_feature_option "NVME" "ssd_base_address" "false"]
    if {$ssd_base == "false"} {
      puts "SSD base address not defined, setting to zero"
      set ssd_base 0
    }
    set_property CONFIG.pcie_nvme_base_address $ssd_base $nvmestr

    # create (stream) interconnects and register slices
    set axis_rd_cmd_ic [tapasco::ip::create_axis_ic axis_rd_cmd_ic_0 1 1]
    set axis_wr_cmd_ic [tapasco::ip::create_axis_ic axis_wr_cmd_ic_0 1 1]
    set axis_rd_rsp_ic [tapasco::ip::create_axis_ic axis_rd_rsp_ic_0 1 1]
    set axis_wr_rsp_ic [tapasco::ip::create_axis_ic axis_wr_rsp_ic_0 1 1]
    set axis_rd_cmd_rs [tapasco::ip::create_axis_reg_slice axis_rd_cmd_rs_0]
    set axis_wr_cmd_rs [tapasco::ip::create_axis_reg_slice axis_wr_cmd_rs_0]
    set axis_rd_rsp_rs [tapasco::ip::create_axis_reg_slice axis_rd_rsp_rs_0]
    set axis_wr_rsp_rs [tapasco::ip::create_axis_reg_slice axis_wr_rsp_rs_0]
    set_property CONFIG.REG_CONFIG {16} $axis_rd_cmd_rs
    set_property CONFIG.REG_CONFIG {16} $axis_wr_cmd_rs
    set_property CONFIG.REG_CONFIG {16} $axis_rd_rsp_rs
    set_property CONFIG.REG_CONFIG {16} $axis_wr_rsp_rs

    # connect AXI ports
    connect_bd_intf_net [get_bd_intf_pins $nvmestr/M_AXI_Doorbells] $m_ssd
    connect_bd_intf_net $s_nvme_queues [get_bd_intf_pins $nvmestr/S_AXI_Queues]
    connect_bd_intf_net $s_nvme_ctrl [get_bd_intf_pins $nvmestr/S_CTRL]
    connect_bd_intf_net $s_read_cmd [get_bd_intf_pins $axis_rd_cmd_ic/S00_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_rd_cmd_ic/M00_AXIS] [get_bd_intf_pins $axis_rd_cmd_rs/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_rd_cmd_rs/M_AXIS] [get_bd_intf_pins $nvmestr/S_AXIS_READ]
    connect_bd_intf_net $s_write_cmd [get_bd_intf_pins $axis_wr_cmd_ic/S00_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_wr_cmd_ic/M00_AXIS] [get_bd_intf_pins $axis_wr_cmd_rs/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_wr_cmd_rs/M_AXIS] [get_bd_intf_pins $nvmestr/S_AXIS_WRITE]
    connect_bd_intf_net [get_bd_intf_pins $nvmestr/M_AXIS_READ] [get_bd_intf_pins $axis_rd_rsp_rs/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_rd_rsp_rs/M_AXIS] [get_bd_intf_pins $axis_rd_rsp_ic/S00_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_rd_rsp_ic/M00_AXIS] $m_read_rsp
    connect_bd_intf_net [get_bd_intf_pins $nvmestr/M_AXIS_WRITE] [get_bd_intf_pins $axis_wr_rsp_rs/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_wr_rsp_rs/M_AXIS] [get_bd_intf_pins $axis_wr_rsp_ic/S00_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $axis_wr_rsp_ic/M00_AXIS] $m_write_rsp
    if {$mem_opt == "uram"} {
      connect_bd_intf_net $s_nvme_data [get_bd_intf_pins $nvmestr/S_AXI_URAM_PRP]
    } else {
      connect_bd_intf_net [get_bd_intf_pins $nvmestr/M_AXI_DDR_NVMe] $m_nvme_ddr
      if {$mem_opt == "on-board-dram"} {
        # connection is not used if we use data buffers in host memory
        connect_bd_intf_net $s_nvme_data [get_bd_intf_pins $nvmestr/S_AXI_PCIe]
      }
    }

    # connect clocks and resets
    set str_aclk $mem_aclk
    set str_resetn $mem_resetn
    set str_ic_resetn $mem_ic_resetn

    connect_bd_net $str_aclk [get_bd_pins $nvmestr/aclk] \
      [get_bd_pins $axis_rd_cmd_ic/ACLK] \
      [get_bd_pins $axis_rd_cmd_ic/M00_AXIS_ACLK] \
      [get_bd_pins $axis_wr_cmd_ic/ACLK] \
      [get_bd_pins $axis_wr_cmd_ic/M00_AXIS_ACLK] \
      [get_bd_pins $axis_rd_rsp_ic/ACLK] \
      [get_bd_pins $axis_rd_rsp_ic/S00_AXIS_ACLK] \
      [get_bd_pins $axis_wr_rsp_ic/ACLK] \
      [get_bd_pins $axis_wr_rsp_ic/S00_AXIS_ACLK] \
      [get_bd_pins $axis_rd_cmd_rs/aclk] \
      [get_bd_pins $axis_wr_cmd_rs/aclk] \
      [get_bd_pins $axis_rd_rsp_rs/aclk] \
      [get_bd_pins $axis_wr_rsp_rs/aclk]
    connect_bd_net $str_resetn [get_bd_pins $nvmestr/aresetn]
    connect_bd_net $str_ic_resetn \
      [get_bd_pins $axis_rd_cmd_ic/ARESETN] \
      [get_bd_pins $axis_rd_cmd_ic/M00_AXIS_ARESETN] \
      [get_bd_pins $axis_wr_cmd_ic/ARESETN] \
      [get_bd_pins $axis_wr_cmd_ic/M00_AXIS_ARESETN] \
      [get_bd_pins $axis_rd_rsp_ic/ARESETN] \
      [get_bd_pins $axis_rd_rsp_ic/S00_AXIS_ARESETN] \
      [get_bd_pins $axis_wr_rsp_ic/ARESETN] \
      [get_bd_pins $axis_wr_rsp_ic/S00_AXIS_ARESETN] \
      [get_bd_pins $axis_rd_cmd_rs/aresetn] \
      [get_bd_pins $axis_wr_cmd_rs/aresetn] \
      [get_bd_pins $axis_rd_rsp_rs/aresetn] \
      [get_bd_pins $axis_wr_rsp_rs/aresetn]
    connect_bd_net $design_aclk [get_bd_pins $axis_rd_cmd_ic/S00_AXIS_ACLK] \
      [get_bd_pins $axis_wr_cmd_ic/S00_AXIS_ACLK] \
      [get_bd_pins $axis_rd_rsp_ic/M00_AXIS_ACLK] \
      [get_bd_pins $axis_wr_rsp_ic/M00_AXIS_ACLK]
    connect_bd_net $design_ic_resetn [get_bd_pins $axis_rd_cmd_ic/S00_AXIS_ARESETN] \
      [get_bd_pins $axis_wr_cmd_ic/S00_AXIS_ARESETN] \
      [get_bd_pins $axis_rd_rsp_ic/M00_AXIS_ARESETN] \
      [get_bd_pins $axis_wr_rsp_ic/M00_AXIS_ARESETN]

    platform::nvme::add_host_ports
    platform::nvme::add_arch_ports
    if {$mem_opt == "on-board-dram"} {
      platform::nvme::add_mem_ports
    }
  }
}

namespace eval nvme {

  proc is_nvme_supported {} {
    return false
  }

  proc add_host_ports {} {
    # add ports to ICs in host subsystem
    puts "Add host ports for NVME plugin"
    set inst [current_bd_instance .]
    current_bd_instance "/host"
    set mem_opt [tapasco::get_feature_option "NVME" "memory" "none"]

    set m_nvme_queues [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_NVME_QUEUES"]
    set m_nvme_ctrl [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_NVME_CTRL"]
    if {$mem_opt == "uram" || $mem_opt == "on-board-dram"} {
      set m_nvme_data [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_NVME_DATA"]
    }
    set out_ic [get_bd_cells out_ic]
    set in_ic [get_bd_cells in_ic]

    set num_mi_out_old [get_property CONFIG.NUM_MI $out_ic]
    if {$mem_opt == "host-dram"} {
      set num_mi_out [expr "$num_mi_out_old + 2"]
    } else {
      set num_mi_out [expr "$num_mi_out_old + 3"]
    }
    set_property -dict [list \
      CONFIG.NUM_MI $num_mi_out \
    ] $out_ic

    connect_bd_intf_net [get_bd_intf_pins $out_ic/[format "M%02d_AXI" $num_mi_out_old]] $m_nvme_queues
    connect_bd_intf_net [get_bd_intf_pins $out_ic/[format "M%02d_AXI" [expr "$num_mi_out_old + 1"]]] $m_nvme_ctrl
    if {$mem_opt == "uram" || $mem_opt == "on-board-dram"} {
      connect_bd_intf_net [get_bd_intf_pins $out_ic/[format "M%02d_AXI" [expr "$num_mi_out_old + 2"]]] $m_nvme_data
    }

    if {$mem_opt == "on-board-dram"} {
      set pcie [get_bd_cells axi_pcie3_0]
      set_property -dict [list \
        CONFIG.pf0_bar2_enabled {true} \
        CONFIG.pf0_bar2_size {128} \
        CONFIG.pf0_bar2_scale {Megabytes} \
        CONFIG.pf0_bar2_64bit {true} \
        CONFIG.pf0_bar2_prefetchable {true} \
        CONFIG.pciebar2axibar_2 {0x0000000008000000} \
      ] $pcie
    }

    set s_ssd [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_NVME_DOORBELL"]
    if {$mem_opt == "host-dram"} {
      set s_ddr_pcie [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DDR_NVME"]
    }
    set num_si_in_old [get_property CONFIG.NUM_SI $in_ic]
    if {$mem_opt == "host-dram"} {
      # additional connection from StreamAdapter to host memory over PCIe
      set num_si_in [expr "$num_si_in_old + 2"]
    } else {
      set num_si_in [expr "$num_si_in_old + 1"]
    }
    set_property -dict [list \
      CONFIG.NUM_SI $num_si_in \
    ] $in_ic
    connect_bd_intf_net [get_bd_intf_pins $in_ic/[format "S%02d_AXI" $num_si_in_old]] $s_ssd
    if {$mem_opt == "host-dram"} {
      connect_bd_intf_net [get_bd_intf_pins $in_ic/[format "S%02d_AXI" [expr "$num_si_in_old + 1"]]] $s_ddr_pcie
    }

    current_bd_instance $inst
  }

  proc add_arch_ports {} {
    # add ports to arch subsystem
    puts "Add arch ports for NVME plugin"
    set inst [current_bd_instance .]
    current_bd_instance "/arch"

    set m_rd_cmd [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 "M_NVME_RD_CMD"]
    set m_wr_cmd [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 "M_NVME_WR_CMD"]
    set s_rd_rsp [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 "S_NVME_RD_RSP"]
    set s_wr_rsp [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 "S_NVME_WR_RSP"]

    set pes [get_bd_cells -filter "NAME =~ *target_ip_*_* && TYPE == ip" -of_objects [get_bd_cells /arch]]
    set rd_cmd_intf [tapasco::get_feature_option "NVME" "axis_read_command" "none"]
    if {$rd_cmd_intf == "none"} {
      error "ERROR: AXI stream interface for NVME read commands not specified"
    }
    set wr_cmd_intf [tapasco::get_feature_option "NVME" "axis_write_command" "none"]
    if {$wr_cmd_intf == "none"} {
      error "ERROR: AXI stream interface for NVME write commands not specified"
    }
    set rd_rsp_intf [tapasco::get_feature_option "NVME" "axis_read_response" "none"]
    if {$rd_rsp_intf == "nono"} {
      error "ERROR: AXI stream interface for NVME read responses not specified"
    }
    set wr_rsp_intf [tapasco::get_feature_option "NVME" "axis_write_response" "none"]
    if {$wr_rsp_intf == "none"} {
      error "ERROR: AXI stream interface for NVME write responses not specified"
    }

    set rd_cmd_match [get_bd_intf_pins -of_objects $pes -filter "vlnv == xilinx.com:interface:axis_rtl:1.0 && MODE == Master && PATH =~ *$rd_cmd_intf"]
    if {[llength $rd_cmd_match] < 1} {
      error "ERROR: Specified AXI stream interface for NVME read commands not found"
    } else {
      foreach intf $rd_cmd_match {
        connect_bd_intf_net $intf $m_rd_cmd
      }
    }

    set wr_cmd_match [get_bd_intf_pins -of_objects $pes -filter "vlnv == xilinx.com:interface:axis_rtl:1.0 && MODE == Master && PATH =~ *$wr_cmd_intf"]
    if {[llength $wr_cmd_match] < 1} {
      error "ERROR: Specified AXI stream interface for NVME write commands not found"
    } else {
      foreach intf $wr_cmd_match {
        connect_bd_intf_net $intf $m_wr_cmd
      }
    }

    set rd_rsp_match [get_bd_intf_pins -of_objects $pes -filter "vlnv == xilinx.com:interface:axis_rtl:1.0 && MODE == Slave && PATH =~ *$rd_rsp_intf"]
    if {[llength $rd_rsp_match] < 1} {
      error "ERROR: Specified AXI stream interface for NVME read responses not found"
    } else {
      foreach intf $rd_rsp_match {
        connect_bd_intf_net $s_rd_rsp $intf
      }
    }

    set wr_rsp_match [get_bd_intf_pins -of_objects $pes -filter "vlnv == xilinx.com:interface:axis_rtl:1.0 && MODE == Slave && PATH =~ *$wr_rsp_intf"]
    if {[llength $wr_rsp_match] < 1} {
      error "ERROR: Specified AXI stream interface for NVME write responses not found"
    } else {
      foreach intf $wr_rsp_match {
        connect_bd_intf_net $s_wr_rsp $intf
      }
    }

    current_bd_instance $inst
  }

  proc add_mem_ports {} {
    # add ports to ICs in host subsystem
    puts "Add host ports for NVME plugin"
    set inst [current_bd_instance .]
    current_bd_instance "/memory"

    set mem_aclk [tapasco::subsystem::get_port "mem" "clk"]
    set mem_aresetn [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
    set s_ddr_nvme [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_DDR_NVME"]

    # add offset to map NVMe accesses into upper 16 MB of DDR address space
    # FIXME increase address width if we use the entire DDR memory space in future TaPaSCo versions
    set str_to_ddr_off [tapasco::ip::create_axi_generic_off "str_to_ddr_off_0"]
    set_property -dict [list CONFIG.ADDRESS_WIDTH {32} \
      CONFIG.BYTES_PER_WORD {64} \
      CONFIG.HIGHEST_ADDR_BIT {31} \
      CONFIG.ID_WIDTH {4} \
      CONFIG.OVERWRITE_BITS {5} \
    ] $str_to_ddr_off

    set mig_ic [get_bd_cells mig_ic]
    set num_si_old [get_property CONFIG.NUM_SI $mig_ic]
    set num_si [expr "$num_si_old + 1"]
    set_property -dict [list CONFIG.NUM_SI $num_si] $mig_ic

    connect_bd_net $mem_aclk [get_bd_pins $str_to_ddr_off/aclk]
    connect_bd_net $mem_aresetn [get_bd_pins $str_to_ddr_off/aresetn]
    connect_bd_intf_net $s_ddr_nvme [get_bd_intf_pins $str_to_ddr_off/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins $str_to_ddr_off/M_AXI] [get_bd_intf_pins $mig_ic/[format "S%02d_AXI" $num_si_old]]

    current_bd_instance $inst
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "NVME"]} {
      set args [lappend args "M_NVME_QUEUES" [list 0x60000 0x10000 0 "PLATFORM_COMPONENT_NVME_QUEUES"]]
      set mem_opt [tapasco::get_feature_option "NVME" "memory" "none"]
      if {$mem_opt == "uram"} {
        set args [lappend args "M_NVME_DATA" [list 0x1000000 0 0x1000000 "PLATFORM_COMPONENT_NVME_DATA"]]
      } else {
        set args [lappend args "M_NVME_DATA" [list 0x8000000 0 0x8000000 ""]]
      }
      if {$mem_opt == "uram"} {
        set args [lappend args "M_NVME_CTRL" [list 0x70000 0x10000 0 "PLATFORM_COMPONENT_NVME_CTRL"]]
      } else {
        set args [lappend args "M_NVME_CTRL" [list 0x100000 0 0x80000 "PLATFORM_COMPONENT_NVME_CTRL"]]
      }
      set args [lappend args "M_NVME_DOORBELL" [list 0 0 [expr "1 << 64"] ""]]
      set args [lappend args "M_DDR_NVME" [list 0 0 [expr "1 << 64"]]]
    }

    return $args
  }
}

tapasco::register_plugin "platform::nvme::addressmap" "post-address-map"
