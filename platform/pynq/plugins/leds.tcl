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
  proc default_led_pins {} {
    return [concat \
      [get_bd_pins -of_objects [::tapasco::subsystem::get arch] -filter { TYPE == intr && DIR == O }] \
      [get_bd_pins -of_objects [::tapasco::subsystem::get intc] -filter { TYPE == intr && DIR == O }] \
    ]
  }

  proc get_width {input} {
    set l [get_property LEFT $input]
    set r [get_property RIGHT $input]
    return [expr $l - $r + 1]
  }

  proc calc_total_width {inputs} {
    set w 0
    foreach i $inputs { incr w [get_width $i] }
    return $w
  }

  proc split_input {input} {
    set width [get_width $input]
    set name [get_property NAME $input]
    set pins {}
    set old_inst [current_bd_instance .]
    set cell [create_bd_cell -type hier "${name}_splitter"]
    current_bd_instance $cell
    for {set i 0} {$i < $width} {incr i} {
      set slice [tapasco::ip::create_xlslice ${name}_$i $width $i]
      connect_bd_net $input [get_bd_pins -of_objects $slice -filter { DIR == I }]
      lappend pins [get_bd_pins -of_objects $slice -filter { DIR == O }]
    }
    current_bd_instance $old_inst
    return $pins
  }

  proc get_led_inputs {inputs} {
    set rlist [list]
    foreach i $inputs {
      set pin [get_bd_pins $i]
      set width [get_width $pin]
      puts "  LED: $pin \[width: $width\]"
      if {$width > 1} {
        set split_pins [split_input $pin]
        foreach p $split_pins { lappend rlist $p }
      } else {
        lappend rlist [get_bd_pins $pin]
      }
    }
    set total_width [calc_total_width $rlist]
    if {$total_width < 6} {
      # create tie-off constant zero
      set zero [tapasco::ip::create_constant zero 1 0]
      set pin [get_bd_pins -of_objects $zero -filter {DIR == "O"}]
      for {set i $total_width} {$i < 6} {incr i} { lappend rlist $pin }
    }
    if {$total_width > 6} {
      puts "  WARNING: can only connect up to 6 LEDs, additional inputs will be discarded"
    }
    return $rlist
  }

  proc create_led_core {{name "gp_led"} {inputs [list]}} {
    puts "Creating LED core ..."
    if {[llength $inputs] == 0} {
      set inputs [default_led_pins]
    }
    set old_inst [current_bd_instance .]
    set cell [create_bd_cell -type hier "LEDs"]
    current_bd_instance $cell

    set inputs [get_led_inputs $inputs]
    puts "  Inputs: $inputs"
    set led_concat [tapasco::ip::create_xlconcat led_concat 6]

    # connect the inputs
    for {set i 0} {$i < 6 && [llength $inputs] > $i} {incr i} {
      set src [lindex $inputs $i]
      set tgt [get_bd_pins $led_concat/In$i]
      puts "  connecting $src to $tgt ..."
      connect_bd_net $src $tgt
    }
    set led [create_bd_port -from 5 -to 0  -dir O led]
    connect_bd_net [get_bd_pins -of_objects $led_concat -filter { DIR == O }] $led

    read_xdc -unmanaged "$::env(TAPASCO_HOME)/platform/pynq/plugins/leds.xdc"

    current_bd_instance $old_inst
    return $led_concat
  }


  proc create_leds {{name "gp_leds"}} {
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

tapasco::register_plugin "platform::leds::create_leds" "pre-wrapper"
