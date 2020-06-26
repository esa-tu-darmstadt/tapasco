# Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
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

if {[tapasco::is_feature_enabled "HBM"]} {
  proc create_custom_subsystem_hbm {{args {}}} {

    set hbmInterfaces [hbm::get_hbm_interfaces]

    hbm::validate_pe_configuration $hbmInterfaces

    set numInterfaces [llength $hbmInterfaces]
    set bothStacks [expr ($numInterfaces > 16)]

    hbm::create_refclk_ports $bothStacks

    hbm::generate_hbm_core $hbmInterfaces
    
  }
}

namespace eval hbm {

  # Extracts AXI-MM masters with HBM access from feature configuration
  proc get_hbm_interfaces {} {
    set hbmInterfaces [list]

    set hbm [tapasco::get_feature "HBM"]

    set value [dict values [dict remove $hbm enabled]]

    foreach kernel $value {
      dict with kernel {
        set core [find_ID $ID]
        # select required number PEs of given type
        set end [expr ($Count - 1)]
        set PEs [lrange [get_bd_cells /arch/target_ip_[format %02d $core]_*] 0 $end]
        foreach PE $PEs {
          foreach interface $Interfaces {
            # select all given interfaces of the given PEs
            set hbmInterfaces [lappend hbmInterfaces [format "%s/%s" $PE $interface]]
          }
        }
      }
    }
    return $hbmInterfaces
  }

  proc validate_pe_configuration {hbmInterfaces} {
    set numInterfaces [llength $hbmInterfaces]

    if { $numInterfaces > 32 } {
      puts "Currently only 32 Master interfaces with HBM connection supported."
      puts "Got $hbmInterfaces"
      exit
    }

    if { $numInterfaces == 0 } {
      puts "No IP with HBM connections found."
      puts "Disable Feature HBM if not used."
      exit
    }
  }

  # Creates input ports for reference clock(s)
  proc create_refclk_ports {bothStacks} {
      set hbm_ref_clk_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 hbm_ref_clk_0 ]
      set_property CONFIG.FREQ_HZ 100000000 $hbm_ref_clk_0

      if {$bothStacks} {
        set hbm_ref_clk_1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 hbm_ref_clk_1 ]
        set_property CONFIG.FREQ_HZ 100000000 $hbm_ref_clk_1
      }
  }

  # Creates HBM configuration for given number of active HBM ports
  proc create_hbm_properties {numInterfaces} {
    # disable APB debug port
    # disable AXI crossbar (global addressing)
    # configure AXI clock freq
    set hbm_properties [list \
      CONFIG.USER_SWITCH_ENABLE_00 {false} \
      CONFIG.USER_SWITCH_ENABLE_01 {false} \
      CONFIG.USER_AXI_INPUT_CLK_FREQ {450} \
      CONFIG.USER_AXI_INPUT_CLK_NS {2.222} \
      CONFIG.USER_AXI_INPUT_CLK_PS {2222} \
      CONFIG.USER_AXI_INPUT_CLK_XDC {2.222} \
      CONFIG.HBM_MMCM_FBOUT_MULT0 {51} \
      CONFIG.USER_XSDB_INTF_EN {FALSE}
    ]

    # configure stacks used
    if {$numInterfaces <= 16} {
      set maxSlaves 16
      lappend hbm_properties \
        CONFIG.USER_HBM_DENSITY {4GB} \
        CONFIG.USER_HBM_STACK {1} \
    } else {
      set maxSlaves 32
      lappend hbm_properties \
        CONFIG.USER_HBM_DENSITY {8GB} \
    }


    # enable HBM ports and memory controllers as required (two ports per mc)
    for {set i $numInterfaces} {$i < $maxSlaves} {incr i} {
      set saxi [format %02s $i]
      lappend hbm_properties CONFIG.USER_SAXI_${saxi} {false}
      if ([even $i]) {
        set mc [format %02s [expr {$i / 2}]]
        lappend hbm_properties CONFIG.USER_MC_ENABLE_${mc} {false}
      }
    }


    # configure memory controllers
    for {set i 0} {$i < $maxSlaves} {incr i} {
      if ([even $i]) {
        set mc [format %s [expr {$i / 2}]]
        lappend hbm_properties CONFIG.USER_MC${mc}_ECC_BYPASS false
        lappend hbm_properties CONFIG.USER_MC${mc}_ECC_CORRECTION false
        lappend hbm_properties CONFIG.USER_MC${mc}_EN_DATA_MASK true
        lappend hbm_properties CONFIG.USER_MC${mc}_TRAFFIC_OPTION {Linear}
        lappend hbm_properties CONFIG.USER_MC${mc}_BG_INTERLEAVE_EN true
      }
    }

    return $hbm_properties
  }

  # Creates HBM clocking infrastructure for a single stack
  proc create_clocking {name port} {
    set group [create_bd_cell -type hier $name]
    set instance [current_bd_instance .]
    current_bd_instance $group

    set hbm_ref_clk [create_bd_pin -type "clk" -dir "O" "hbm_ref_clk"]
    set axi_clk_0 [create_bd_pin -type "clk" -dir "O" "axi_clk_0"]
    set axi_clk_1 [create_bd_pin -type "clk" -dir "O" "axi_clk_1"]
    set axi_clk_2 [create_bd_pin -type "clk" -dir "O" "axi_clk_2"]
    set axi_clk_3 [create_bd_pin -type "clk" -dir "O" "axi_clk_3"]
    set axi_clk_4 [create_bd_pin -type "clk" -dir "O" "axi_clk_4"]
    set axi_clk_5 [create_bd_pin -type "clk" -dir "O" "axi_clk_5"]
    set axi_clk_6 [create_bd_pin -type "clk" -dir "O" "axi_clk_6"]
    set axi_reset [create_bd_pin -type "rst" -dir "O" "axi_reset"]
    set mem_peripheral_aresetn [create_bd_pin -type "rst" -dir "I" "mem_peripheral_aresetn"]

    set ibuf [tapasco::ip::create_util_buf ibuf]
    set_property -dict [ list CONFIG.C_BUF_TYPE {IBUFDS}  ] $ibuf

    connect_bd_intf_net $port [get_bd_intf_pins $ibuf/CLK_IN_D]

    set clk_wiz [tapasco::ip::create_clk_wiz clk_wiz]
    set_property -dict [list CONFIG.PRIM_SOURCE {No_buffer} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {450} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {450} CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {450} CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {450} CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {450} CONFIG.CLKOUT6_REQUESTED_OUT_FREQ {450} CONFIG.CLKOUT7_REQUESTED_OUT_FREQ {450} CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT3_USED {true} CONFIG.CLKOUT4_USED {true} CONFIG.CLKOUT5_USED {true} CONFIG.CLKOUT6_USED {true} CONFIG.CLKOUT7_USED {true} CONFIG.RESET_TYPE {ACTIVE_LOW} CONFIG.NUM_OUT_CLKS {7} CONFIG.RESET_PORT {resetn}] $clk_wiz

    connect_bd_net [get_bd_pins $ibuf/IBUF_OUT] $hbm_ref_clk
    connect_bd_net [get_bd_pins $ibuf/IBUF_OUT] [get_bd_pins $clk_wiz/clk_in1]

    connect_bd_net $mem_peripheral_aresetn [get_bd_pins $clk_wiz/resetn]

    set reset_generator [tapasco::ip::create_logic_vector reset_generator]
    set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {and} CONFIG.LOGO_FILE {data/sym_andgate.png}] $reset_generator

    connect_bd_net $mem_peripheral_aresetn [get_bd_pins $reset_generator/Op1]
    connect_bd_net [get_bd_pins $clk_wiz/locked] [get_bd_pins $reset_generator/Op2]

    for {set i 0} {$i < 7} {incr i} {
      set incr [expr $i + 1]
      connect_bd_net [get_bd_pins axi_clk_${i}] [get_bd_pins $clk_wiz/clk_out${incr}]
    }

    connect_bd_net $axi_reset [get_bd_pins $reset_generator/Res]

    current_bd_instance $instance
    connect_bd_net [get_bd_pins mem_peripheral_aresetn] $mem_peripheral_aresetn
    return $group
  }

  # Connects a range of HBM AXI clocks with the outputs of a clocking infrastructure
  proc connect_clocking {clocking hbm startInterface numInterfaces} {
    for {set i 0} {$i < $numInterfaces} {incr i} {
        set hbm_index [format %02s [expr $i + $startInterface]]
        set block_index [expr $i < 16 ? 0 : 1]
        set clk_index [expr ($i % 16) / 2]
        set clk_index [expr $clk_index < 7 ? $clk_index : 6]
        connect_bd_net [get_bd_pins $clocking/axi_reset] [get_bd_pins $hbm/AXI_${hbm_index}_ARESET_N]
        connect_bd_net [get_bd_pins $clocking/axi_clk_${clk_index}] [get_bd_pins $hbm/AXI_${hbm_index}_ACLK]
      }
  }

  # Ṕrovides HBM access for the given AXI-MM masters
  proc generate_hbm_core {hbmInterfaces} {
    if {[tapasco::is_feature_enabled "HBM"]} {
      puts "Generating HBM Core"
      set numInterfaces [llength $hbmInterfaces]
      set bothStacks [expr ($numInterfaces > 16)]

      set hbm_properties [create_hbm_properties $numInterfaces]

      # create and configure HBM IP
      set hbm [ create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 "hbm_0" ]
      set_property -dict $hbm_properties $hbm

      # Disabling the APB debug port is only possible in Vivado 2019.2 and newer
      if { [::tapasco::vivado_is_newer "2019.2"] == 0 } {
        set const [tapasco::ip::create_constant const_zero 1 0]
        connect_bd_net [get_bd_pins const_zero/dout] [get_bd_pins $hbm/APB_0_PENABLE]
        if {$bothStacks} {
          connect_bd_net [get_bd_pins const_zero/dout] [get_bd_pins $hbm/APB_1_PENABLE]
        }
      } else {
        set_property CONFIG.USER_APB_EN {false} $hbm
      }

      # create and connect clocking infrastructure for left stack
      set clocking_0 [create_clocking "clocking_0" [get_bd_intf_ports /hbm_ref_clk_0]]
      connect_clocking $clocking_0 $hbm 0 [expr min($numInterfaces,16)]
      connect_bd_net [get_bd_pins $clocking_0/hbm_ref_clk] [get_bd_pins $hbm/HBM_REF_CLK_0]

      connect_bd_net [get_bd_pins $clocking_0/hbm_ref_clk] [get_bd_pins $hbm/APB_0_PCLK]
      connect_bd_net [get_bd_pins /host/axi_pcie3_0/user_lnk_up] [get_bd_pins $hbm/APB_0_PRESET_N]

      if {$bothStacks} {
        # create and connect clocking infrastructure for right stack
        set clocking_1 [create_clocking "clocking_1" [get_bd_intf_ports /hbm_ref_clk_1]]
        connect_clocking $clocking_1 $hbm 16 [expr $numInterfaces - 16]
        connect_bd_net [get_bd_pins $clocking_1/hbm_ref_clk] [get_bd_pins $hbm/HBM_REF_CLK_1]

        connect_bd_net [get_bd_pins $clocking_1/hbm_ref_clk] [get_bd_pins $hbm/APB_1_PCLK]
        connect_bd_net [get_bd_pins /host/axi_pcie3_0/user_lnk_up] [get_bd_pins $hbm/APB_1_PRESET_N]
      }

      # remove standard memory interconnect network
      delete_bd_objs [get_bd_cells /arch/out_*]
      delete_bd_objs [get_bd_intf_pins /arch/M_MEM_*]

      for {set i 0} {$i < $numInterfaces} {incr i} {
        variable master [lindex $hbmInterfaces $i]

        set pin [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 /arch/M_AXI_HBM_${i}]
        connect_bd_intf_net $pin $master

        set hbm_index [format %02s $i]

        # create smartconnect for clock domain conversion, protocol conversion (AXI4->AXI3) and data width conversion
        set converter [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_${i}]
        set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_CLKS {2} CONFIG.HAS_ARESETN {0}] $converter
        
        # create connections between PE and smartconnect, and smartconnect and HBM

        connect_bd_net [get_bd_pins design_clk] [get_bd_pins $converter/aclk]
        connect_bd_net [get_bd_pins $hbm/AXI_${hbm_index}_ACLK] [get_bd_pins $converter/aclk1]

        if {[platform::is_regslice_enabled "hbm_pe" false] || [platform::is_regslice_enabled [format "hbm_pe%s" $hbm_index] false]} {
          # insert register slice between PE and smartconnect
          set regslice_pre [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 regslice_pre_${i}]
          set_property -dict [list CONFIG.REG_AW {15} CONFIG.REG_AR {15} CONFIG.REG_W {15} CONFIG.REG_R {15} CONFIG.REG_B {15} CONFIG.USE_AUTOPIPELINING {1}] $regslice_pre

          connect_bd_intf_net $pin [get_bd_intf_pins $regslice_pre/S_AXI]
          connect_bd_intf_net [get_bd_intf_pins $regslice_pre/M_AXI] [get_bd_intf_pins $converter/S00_AXI]

          connect_bd_net [get_bd_pins design_clk] [get_bd_pins $regslice_pre/aclk]
          connect_bd_net [get_bd_pins design_interconnect_aresetn] [get_bd_pins $regslice_pre/aresetn]
        } else {
          connect_bd_intf_net $pin [get_bd_intf_pins $converter/S00_AXI]
        }

        set address_offset [tapasco::ip::create_axioffset_hbm offset_${i}]
        set offset [format "0x0000000%02x0000000" $i]
        set_property -dict [list CONFIG.offset $offset CONFIG.offset_bits {5}] $address_offset
        connect_bd_intf_net [get_bd_intf_pins $converter/M00_AXI] [get_bd_intf_pins $address_offset/S_AXI]
        connect_bd_net [get_bd_pins $hbm/AXI_${hbm_index}_ACLK] [get_bd_pins $address_offset/CLK]
        connect_bd_net [get_bd_pins $hbm/AXI_${hbm_index}_ARESET_N] [get_bd_pins $address_offset/RST_N]

        if {[platform::is_regslice_enabled "hbm_hbm" false] || [platform::is_regslice_enabled [format "hbm_hbm%s" $hbm_index] false]} {
          # insert register slice between smartconnect and HBM
          set regslice_post [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 regslice_post_${i}]
          set_property -dict [list CONFIG.REG_AW {15} CONFIG.REG_AR {15} CONFIG.REG_W {15} CONFIG.REG_R {15} CONFIG.REG_B {15} CONFIG.USE_AUTOPIPELINING {1}] $regslice_post

          connect_bd_intf_net [get_bd_intf_pins $address_offset/M_AXI] [get_bd_intf_pins $regslice_post/S_AXI]
          connect_bd_intf_net [get_bd_intf_pins $regslice_post/M_AXI] [get_bd_intf_pins $hbm/SAXI_${hbm_index}]
          connect_bd_net [get_bd_pins $hbm/AXI_${hbm_index}_ACLK] [get_bd_pins $regslice_post/aclk]
          connect_bd_net [get_bd_pins $hbm/AXI_${hbm_index}_ARESET_N] [get_bd_pins $regslice_post/aresetn]
        } else {
          connect_bd_intf_net [get_bd_intf_pins $address_offset/M_AXI] [get_bd_intf_pins $hbm/SAXI_${hbm_index}]
        }

      }

      # recreate memory interconnect network for AXI-MM masters not connected to HBM
      current_bd_instance /arch
      set mgroups [platform::max_masters]
      set masters [ldiff [lsort -dictionary [tapasco::get_aximm_interfaces [get_bd_cells /arch/target_ip_*]]] $hbmInterfaces]
      set arch_mem_ics [arch::arch_create_mem_interconnects $mgroups [llength $masters]]
      arch::arch_connect_mem $arch_mem_ics $masters
      catch {arch::arch_connect_clocks} issue
      catch {arch::arch_connect_resets} issue

      # apply constraints for one or both stacks
      current_bd_instance /hbm
      set constraints_l "$::env(TAPASCO_HOME_TCL)/platform/xupvvh/plugins/hbm_l.xdc"
      read_xdc $constraints_l
      set_property PROCESSING_ORDER EARLY [get_files $constraints_l]

      if {$bothStacks} {
        set constraints_r "$::env(TAPASCO_HOME_TCL)/platform/xupvvh/plugins/hbm_r.xdc"
        read_xdc $constraints_r
        set_property PROCESSING_ORDER EARLY [get_files $constraints_r]
      }


    }
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "HBM"]} {
      set hbmInterfaces [get_hbm_interfaces]
      for {set i 0} {$i < [llength $hbmInterfaces]} {incr i} {
        set args [lappend args M_AXI_HBM_${i} [list 0 0 -1 ""]]
      }
      
    }
    return $args
  }

  proc ldiff {a b} {
    lmap elem $a {
        expr {[lsearch -exact $b $elem] > -1 ? [continue] : $elem}
    }
  }

  proc lmap {varname listval body} {
    upvar 1 $varname var
    set temp [list]
    foreach var $listval {
        lappend temp [uplevel 1 $body]
    }
    set temp
  }

  proc even x {expr {($x % 2) == 0}}

  proc find_ID {input} {
    set composition [tapasco::get_composition]
    for {set o 0} {$o < [llength $composition] -1} {incr o} {
      if {[regexp ".*:$input:.*" [dict get $composition $o vlnv]]} {
        return $o
      }
    }
    return -1
  }


}


tapasco::register_plugin "platform::hbm::addressmap" "post-address-map"