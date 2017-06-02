#
# Copyright (C) 2017 Jens Korinth, TU Darmstadt
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
# @file   leds.tcl
# @brief  Plugin to map general purpose LEDs on-board to signals.
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval leds {
  set vlnv "ESA:user:GP_LED:1.0"
  set default_led_pins [list \
    "/PCIe/axi_pcie3_0/user_link_up" \
    "/PCIe/axi_pcie3_0/msi_enable" \
    "/Memory/mig/init_calib_complete" \
    "/Resets/pcie_peripheral_aresetn" \
    "/Resets/design_clk_peripheral_aresetn" \
  ]

  proc get_led_inputs {inputs} {
    if {[llength $inputs] > 6} {
      puts "  WARNING: can only connect up to 6 LEDs, additional inputs will be discarded"
    }
    set rlist [list]
    for {set i 0} {$i < 6 && [llength $inputs] > $i} {incr i} {
      set pin [lindex $inputs $i]
      puts "  LED $i: $pin"
      lappend rlist [get_bd_pins $pin]
    }
    if {[llength $inputs] < 6} {
      # create tie-off constant one
      set one [tapasco::createConstant one 1 0]
      set onepin [get_bd_pins -of_objects $one -filter {DIR == "O"}]
      for {} {$i < 6} {incr i} {
        lappend rlist $onepin
      }
    }
    return $rlist
  }

  proc create_led_core {{name "gp_led"} {inputs [list]}} {
    variable vlnv
    puts "Creating LED core ..."
    puts "  VLNV: $vlnv"
    if {[llength $inputs] == 0} {
      set inputs $default_led_pins
    }
    set inputs [get_led_inputs $inputs]
    puts "  Inputs: $inputs"
    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    set port [create_bd_port -from 7 -to 0 -dir "O" "LED_Port"]
    connect_bd_net [get_bd_pins $inst/LED_Port] $port
    read_xdc "$::env(TAPASCO_HOME)/common/ip/GP_LED_1.0/gp_led.xdc"

    # connect the inputs
    for {set i 0} {$i < 6 && [llength $inputs] > $i} {incr i} {
      set src [lindex $inputs $i]
      set tgt [get_bd_pins [format "$inst/IN_%d" $i]]
      puts "  connecting $src to $tgt ..."
      connect_bd_net $src $tgt
    }
    return $inst
  }


  proc create_leds {{name "gp_leds"}} {
    variable vlnv
    if {[tapasco::is_platform_feature_enabled "LED"]} {
      puts "Implementing Platform feature LED ..."
      # create and connect LED core
      set const_one [tapasco::createConstant "const_one" 1 1]
      set gp_led [create_led_core "gp_led" [dict get [tapasco::get_platform_feature "LED"] "inputs"]]
      set pcie_aclk [get_bd_pins "/PCIe/pcie_aclk"]
      set pcie_aresetn [get_bd_pins "/PCIe/pcie_aresetn"]
      set pcie_aclk_net [get_bd_net -of_objects $pcie_aclk]
      set pcie_aresetn_net [get_bd_net -of_objects $pcie_aresetn]
      connect_bd_net -net pcie_aclk_net $pcie_aclk [get_bd_pins $gp_led/aclk]
      connect_bd_net -net pcie_aresetn_net [get_bd_pins "/PCIe/pcie_aresetn"] [get_bd_pins $gp_led/aresetn]
    }
    return {}
  }
}

tapasco::register_plugin "platform::leds::create_leds" "post-platform"
