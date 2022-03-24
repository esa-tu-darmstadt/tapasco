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

namespace eval arch {
  namespace export create
  namespace export get_address_map

  proc next_valid_address {addr range} {
    return [expr (($addr / $range) + ($addr % $range > 0 ? 1 : 0)) * $range]
  }

  # Returns the address map of the current composition.
  # Format: <INTF> -> <BASE ADDR> <RANGE> <KIND>
  # Kind is either memory, register or master.
  # Must be implemented by Platforms.
  proc get_address_map {offset} {
    if {$offset == ""} { set offset [platform::get_pe_base_address] }
    set ret [dict create]
    set pes [lsort [get_processing_elements]]

    foreach pe $pes {
      set reg_segs [lsort [get_bd_addr_segs -filter { USAGE == register } $pe/*]]
      set mem_segs [lsort [get_bd_addr_segs -filter { USAGE == memory } $pe/*]]
      if {[llength $reg_segs] <= 1 && [llength $mem_segs] <= 1} {
        puts "  processing $pe registers ..."
        for {set i 0} {$i < [llength $reg_segs]} {incr i} {
          set seg [lindex $reg_segs $i]
          puts "    seg: $seg"
          if {[get_property MODE [get_bd_intf_pins -of_objects $seg]] == "Master"} {
            puts "    skipping master seg $seg"
          } else {
            set intf [get_bd_intf_pins -of_objects $seg]
            set range [get_property RANGE $seg]
            set offset [next_valid_address $offset $range]
            ::platform::addressmap::add_processing_element [llength [dict keys $ret]] $offset $range
            dict set ret $intf "interface $intf [format "offset 0x%08x range 0x%08x" $offset $range] kind register"
            incr offset $range
          }
        }
        puts "  processing $pe memories ..."
        for {set i 0} {$i < [llength $mem_segs]} {incr i} {
          set seg [lindex $mem_segs $i]
          puts "    seg: $seg"
          if {[get_property MODE [get_bd_intf_pins -of_objects $seg]] == "Master"} {
            puts "    skipping master seg $seg"
          } else {
            set intf [get_bd_intf_pins -of_objects $seg]
            set range [get_property RANGE $seg]
            set offset [next_valid_address $offset $range]
            ::platform::addressmap::add_processing_element [llength [dict keys $ret]] $offset $range
            dict set ret $intf "interface $intf [format "offset 0x%08x range 0x%08x" $offset $range] kind memory"
            incr offset $range
          }
        }
      } else {
        # if there is more than one reg/mem interface, we assume that the user knows what they are doing and add them in the same order
        puts "  processing $pe registers and memories ..."
        set all_segs [lsort [get_bd_addr_segs $pe/*]]
        for {set i 0} {$i < [llength $all_segs]} {incr i} {
          set seg [lindex $all_segs $i]
          puts "    seg: $seg"
          if {[get_property MODE [get_bd_intf_pins -of_objects $seg]] == "Master"} {
            puts "    skipping master seg $seg"
          } else {
            set intf [get_bd_intf_pins -of_objects $seg]
            set range [get_property RANGE $seg]
            set usage [get_property USAGE $seg]
            set offset [next_valid_address $offset $range]
            ::platform::addressmap::add_processing_element [llength [dict keys $ret]] $offset $range
            if { $usage == "register" } {
              dict set ret $intf "interface $intf [format "offset 0x%08x range 0x%08x" $offset $range] kind register"
            } else {
              dict set ret $intf "interface $intf [format "offset 0x%08x range 0x%08x" $offset $range] kind memory"
            }
            incr offset $range
          }
        }
      }
    }
    return $ret
  }

}
