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

namespace eval leds {
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
      if {$pin == {}} {
        puts "  LED: $i"
        puts "  WARNING: pin $i not found in block design, discarding signal"
      } else {
        set width [get_width $pin]
        puts "  LED: $pin \[width: $width\]"
        if {$width > 1} {
          set split_pins [split_input $pin]
          foreach p $split_pins { lappend rlist $p }
        } else {
          lappend rlist [get_bd_pins $pin]
        }
      }
    }
    set total_width [calc_total_width $rlist]
    if {$total_width < [get_led_count]} {
      # create tie-off constant zero
      set zero [tapasco::ip::create_constant zero 1 0]
      set pin [get_bd_pins -of_objects $zero -filter {DIR == "O"}]
      for {set i $total_width} {$i < [get_led_count]} {incr i} { lappend rlist $pin }
    }
    if {$total_width > [get_led_count]} {
      puts "  WARNING: can only connect up to [get_led_count] LEDs, additional inputs will be discarded"
    }
    return $rlist
  }

  proc create_led_core {{inputs [list]}} {
    puts "Creating LED port ..."
    if {[llength $inputs] == 0} {
      set inputs [get_default_pins]
    }
    set inputs [get_led_inputs $inputs]
    puts "  Inputs: $inputs"
    set port [create_bd_port -from [expr [get_led_count] - 1] -to 0 -dir "O" [get_led_port_name]]
    set led_concat [tapasco::ip::create_xlconcat led_concat [get_led_count]]

    # connect the inputs
    for {set i 0} {$i < [get_led_count] && [llength $inputs] > $i} {incr i} {
      set src [lindex $inputs $i]
      set tgt [get_bd_pins $led_concat/In$i]
      puts "  connecting $src to $tgt ..."
      connect_bd_net $src $tgt
    }
    connect_bd_net [get_bd_pins -of_objects $led_concat -filter { DIR == O }] $port

    load_constraints
  }

  proc create_leds {} {
    if {[tapasco::is_feature_enabled "LED"]} {
      puts "Implementing Platform feature LED ..."
      # create and connect LED core
      set f [tapasco::get_feature "LED"]
      set inputs [list]
      if {[dict exists $f "inputs"]} { set inputs [dict get $f "inputs"] }
      create_led_core $inputs
    }
    return {}
  }

  # the following functions should be implemented for each platform
  proc get_led_port_name {} {
    error "LED feature not implemented for this platform!"
  }

  proc get_led_count {} {
    error "LED feature not implemented for this platform!"
  }

  proc get_default_pins {} {
    error "LED feature not implemented for this platform!"
  }

  proc load_constraints {} {
    error "LED feature not implemented for this platform!"
  }
}

tapasco::register_plugin "platform::leds::create_leds" "post-platform"
