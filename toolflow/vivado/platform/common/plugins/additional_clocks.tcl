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

##### Internal configuration format #####
#   A dictionary containg the parsed configuration
#   The dictionary maps clock names to the configured properties of the clock:
#    - name: name of the clock
#    - freq: the frequency in mhz
#    - pin_list: a list of pins (from PEs) which the clock should be connected to

namespace eval additional_clocks {

  proc create_clocks {} {
    if {[tapasco::is_feature_enabled "ADDITIONAL_CLOCKS"]} {
      set config [parse_configuration false]

      set num_clocks [dict size $config]
      set freqs [list]
      set names [list]
      foreach key [dict keys $config] {
        set clock [dict get $config $key]
        dict with clock {
          lappend freqs $freq
          lappend names $name
       }
      }
      # platform::create_clocks wizard $num_clocks $freqs
      # for {set i 0} {$i < $num_clocks} {incr i} {
      #   set j [expr $i + 1]
      #   set pin [create_bd_pin -type "clk" -dir "O" [lindex $names $i]]
      #   connect_bd_net [get_bd_pins wizard/clk_out$j] $pin
      # }
      set design_clk_wiz [get_bd_cells /memory/design_clk_wiz]
      for {set i 0} {$i < $num_clocks} {incr i} {
        set j [expr $i + 2]
        set_property -dict [list \
          CONFIG.CLKOUT${j}_USED {true} \
          CONFIG.CLKOUT${j}_REQUESTED_OUT_FREQ [lindex $freqs $i] \
          CONFIG.CLK_OUT${j}_PORT [lindex $names $i] \
        ] $design_clk_wiz
      }

      connect_pes $config
    }
  }

  proc connect_clocks {} {
    if {[tapasco::is_feature_enabled "ADDITIONAL_CLOCKS"]} {
      #connect_bd_net [get_bd_pins /additional_clocks/mem_clk] [get_bd_pins /additional_clocks/wizard/clk_in]
      #set pin [get_bd_pins /clocks_and_resets/design_rst_gen/ext_reset_in]
      #connect_bd_net $pin [get_bd_pins /additional_clocks/wizard/resetn]
      #disconnect_bd_net [get_bd_nets -of_objects $pin] $pin
      #connect_bd_net $pin [get_bd_pins /additional_clocks/wizard/locked]

      set config [parse_configuration false]
      connect_pes $config
    }
  }

  proc connect_pes {config} {
    foreach key [dict keys $config] {
      set clock [dict get $config $key]
      dict with clock {
        foreach pin $pin_list {
          set pin [get_bd_pins $pin]
          disconnect_bd_net [get_bd_nets -of_objects $pin] $pin
          connect_bd_net [get_bd_pins /memory/design_clk_wiz/$name] $pin
        }
      }
    }
  }


  ###### START PARSE CONFIGURATION ######

  # Parses the JSON configuration
  # @param true if currently in the phase of validating the configuration
  # @return a dictionary containing the parsed configuration. See Internal configuration format at the top of this file
  proc parse_configuration {validation} {
    variable config [tapasco::get_feature "ADDITIONAL_CLOCKS"]
    dict with config {
      set available_PEs [build_pe_dict $validation]

      foreach clk $clocks {
        dict with clk {
          dict set available_clocks $name $clk
          dict set available_clocks $name pin_list [list]
        }
      }

      foreach b $pes {
        dict with b {
          if {![dict exists $available_PEs $ID]} {
            puts "Invalid ADDITIONAL_CLOCKS Configuration: No PE of type $ID in your composition."
            exit
          }

          set pe_list [dict get $available_PEs $ID]
          set count [llength $pe_list]
          dict set available_PEs $ID {}

          foreach PE $pe_list {
            foreach mapping $mappings {
              dict with mapping {

                if {![dict exists $available_clocks $clock_name]} {
                  puts "Invalid ADDITIONAL_CLOCKS Configuration: Clock $clock_name not specified"
                  exit
                }
                set pin_list [dict get $available_clocks $clock_name pin_list]
                set new_pin_list [lappend pin_list "$PE/$pin"]
                dict set available_clocks $clock_name pin_list $new_pin_list
                
              }
            }
          }
        }
      }
      return $available_clocks
    }
  }

  # Build a dictionary containing all PEs in the composition
  # @param true if currently in the phase of validating the configuration
  # @return a dictionary mapping types (of PEs) to a list containing all PEs of that type in the current composition
  proc build_pe_dict {validation} {
    set composition [tapasco::get_composition]
    for {set i 0} {$i < [llength $composition]} {incr i 2} {
      set PEs [lindex $composition [expr $i + 1]]
      set comp_index [lindex $composition $i]
      dict with PEs {
        regexp {.*:.*:(.*):.*} $vlnv -> ip
        if {$validation} {
          dict set available_PEs $ip [lrepeat $count $ip]
        } else {
          dict set available_PEs $ip [get_bd_cells -filter "NAME =~ *target_ip_[format %02d $comp_index]_* && TYPE == ip" -of_objects [get_bd_cells /arch]]
        }
      }
    }
    return $available_PEs
  }

  ###### END PARSE CONFIGURATION ######


  ###### START VALIDATE CONFIGURATION ######

  # Validates the ADDITIONAL_CLOCKS configuration provided by the user
  proc validate_clocks {} {
    if {[tapasco::is_feature_enabled "ADDITIONAL_CLOCKS"]} {
      set config [parse_configuration true]
    }
    return
  }

  ###### END VALIDATE CONFIGURATION ######
  
}



tapasco::register_plugin "platform::additional_clocks::validate_clocks" "pre-arch"
tapasco::register_plugin "platform::additional_clocks::create_clocks" "post-wiring"
