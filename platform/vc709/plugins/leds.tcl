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
    "/host/axi_pcie3_0/user_link_up" \
    "/memory/mig/init_calib_complete" \
    "/clocks_and_resets/host_peripheral_aresetn" \
    "/clocks_and_resets/design_peripheral_aresetn" \
  ]

  proc get_led_inputs {inputs} {
    if {[llength $inputs] > 6} {
      puts "  WARNING: can only connect up to 6 LEDs, additional inputs will be discarded"
    }
    set rlist [list]
    # create tie-off constant zero
    set zero [tapasco::ip::create_constant one 1 0]
    set zero_pin [get_bd_pins -of_objects $zero -filter {DIR == "O"}]

    for {set i 0} {$i < 6 && [llength $inputs] > $i} {incr i} {
      set pin [lindex $inputs $i]
      puts "  LED $i: $pin"
      set bd_pin [get_bd_pins $pin]
      if {$bd_pin != {}} {
        lappend rlist $bd_pin
      } else {
        if {$pin != {}} {
          puts "  WARNING: pin $pin not found in block design, discarding signal"
        }
        lappend rlist $zero_pin
      }
    }
    if {[llength $inputs] < 6} {
      for {} {$i < 6} {incr i} {
        lappend rlist $zero_pin
      }
    }
    if {[lsearch $rlist $zero_pin] == -1} {
      # delete the constant
      delete_bd_objs $zero
    }
    return $rlist
  }

  proc create_led_core {{name "gp_led"} {inputs [list]}} {
    variable vlnv
    variable default_led_pins
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
    read_xdc -unmanaged "$::env(TAPASCO_HOME)/common/ip/GP_LED_1.0/gp_led.xdc"

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
    if {[tapasco::is_feature_enabled "LED"]} {
      puts "Implementing Platform feature LED ..."
      # create and connect LED core
      set const_one [tapasco::ip::create_constant "const_one" 1 1]
      set f [tapasco::get_feature "LED"]
      set inputs [list]
      if {[dict exists $f "inputs"]} { set inputs [dict get $f "inputs"] }
      set gp_led [create_led_core "gp_led" $inputs]
      set clk [get_bd_pins "/clocks_and_resets/host_clk"]
      set resetn [get_bd_pins "/clocks_and_resets/host_peripheral_aresetn"]
      connect_bd_net $clk [get_bd_pins $gp_led/aclk]
      connect_bd_net $resetn [get_bd_pins $gp_led/aresetn]
    }
    return {}
  }
}

tapasco::register_plugin "platform::leds::create_leds" "post-platform"
