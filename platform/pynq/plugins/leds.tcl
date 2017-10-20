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
  set default_led_pins [list "/uArch/irq_0"]

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
    puts "rlist = $rlist"
    return $rlist
  }

  proc create_led_core {{name "gp_led"} {inputs [list]}} {
    variable default_led_pins
    puts "Creating LED core ..."
    if {[llength $inputs] == 0} {
      set inputs $default_led_pins
    }
    set inputs [get_led_inputs $inputs]
    puts "  Inputs: $inputs"
    set led_concat [tapasco::createConcat led_concat 6]

    # connect the inputs
    for {set i 0} {$i < 6 && [llength $inputs] > $i} {incr i} {
      set src [lindex $inputs $i]
      set tgt [get_bd_pins $led_concat/In$i]
      puts "  connecting $src to $tgt ..."
      connect_bd_net $src $tgt
    }
    set led [create_bd_port -from 5 -to 0  -dir O led]
    connect_bd_net [get_bd_pins -of_objects $led_concat -filter { DIR == O }] $led

    read_xdc "$::env(TAPASCO_HOME)/platform/pynq/plugins/leds.xdc"
    return $led_concat
  }


  proc create_leds {{name "gp_leds"}} {
    variable default_led_pins
    if {[tapasco::is_feature_enabled "LED"]} {
      puts "Implementing Platform feature LED ..."
      # create and connect LED core
      set feature [tapasco::get_feature "LED"]
      set inputs {}
      if {[dict exists feature "inputs"]} { set inputs [dict get feature "inputs"] }
      set gp_led [create_led_core "gp_led" $inputs]
    }
    return {}
  }
}

tapasco::register_plugin "platform::leds::create_leds" "post-platform"
