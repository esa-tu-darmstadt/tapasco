#
# Copyright (C) 2018 Jens Korinth, TU Darmstadt
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
# @file		addressmap.tcl
#apasco @brief	Helper procs to maintain an address map of components.
# @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval addressmap {
  namespace export add_platform_component
  namespace export add_processing_element
  namespace export get_platform_component_bases
  namespace export get_processing_element_bases

  set platform_components [dict create]
  set platform_components_order [list]
  set processing_elements [dict create]

  proc get_num_slots {} {
    set f [open "$::env(TAPASCO_HOME)/platform/common/include/platform_global.h" "r"]
    set c [read $f]
    close $f
    regexp {define\s+PLATFORM_NUM_SLOTS\s+(\d+)} $c _ num_slots
    return $num_slots
  }

  for {set i 0} {$i < 128} {incr i} {
    if     {$i == 0} { lappend platform_components_order "STATUS" } \
    elseif {$i == 1} { lappend platform_components_order "MDM" } \
    elseif {$i == 2} { lappend platform_components_order "ATSPRI" } \
    elseif {$i >= 15 && $i <= 31} {
      lappend platform_components_order [format "INTC_%02d" [expr $i - 16]]
    } \
    elseif {$i >= 32 && $i <= 47} {
      lappend platform_components_order [format "MSIX_%02d" [expr $i - 32]]
    } \
    elseif {$i >= 48 && $i <= 63} {
      lappend platform_components_order [format "DMA_%02d"  [expr $i - 48]]
    } \
    elseif {$i >= 64 && $i <= 127} {
      lappend platform_components_order [format "MISC_%02d" [expr $i - 64]]
    } \
    else {
      lappend platform_components_order [format "RESERVED_%03d" $i]
    }
  }

  proc add_platform_component {name base} {
    variable platform_components
    puts "Adding platform component $name at $base ..."
    if {[dict exists $platform_components $name]} {
      puts "WARNING: platform component $name already exists, overwriting!"
    }
    dict set platform_components $name $base
  }

  proc get_platform_component {name} {
    variable platform_components
    if {[dict exists $platform_components $name]} {
      return [dict get $platform_components $name]
    }
    return 0
  }

  proc get_platform_component_bases {} {
    variable platform_components
    variable platform_components_order
    foreach c $platform_components_order {
      lappend ret [get_platform_component $c]
    }
    return $ret
  }

  proc add_processing_element {slot base} {
    variable processing_elements
    puts "Adding processing element in slot $slot with base $base ..."
    if {[dict exists $processing_elements $slot]} {
      puts "WARNING: processing element in slot $slot already exists, overwriting!"
    }
    dict set processing_elements $slot $base
  }

  proc get_processing_element {slot} {
    variable processing_elements
    if {[dict exists $processing_elements $slot]} {
      return [dict get $processing_elements $slot]
    }
    return 0
  }

  proc get_processing_element_bases {} {
    variable processing_elements
    for {set i 0} {$i < [get_num_slots]} {incr i} {
      lappend ret [get_processing_element $i]
    }
    return $ret
  }

  proc assign_address {address_map master base {stride 0} {range 0}} {
    foreach seg [lsort [get_bd_addr_segs -addressables -of_objects $master]] {
      puts [format "  $master: $seg -> 0x%08x (range: 0x%08x)" $base $range]
      set sintf [get_bd_intf_pins -of_objects $seg]
      if {$range <= 0} { set range [get_property RANGE $seg] }
      set kind [get_property USAGE $seg]
      dict set address_map $sintf "interface $sintf offset $base range $range kind $kind"
      if {$stride == 0} { incr base $range } else { incr base $stride }
    }
    return $address_map
  }

  proc construct_address_map {{map ""}} {
    if {$map == ""} { set map [::platform::get_address_map [::platform::get_pe_base_address]] }
    puts "ADDRESS MAP: $map"
    set seg_i 0
    foreach space [get_bd_addr_spaces] {
      puts "space: $space"
      set intfs [get_bd_intf_pins -quiet -of_objects $space -filter { MODE == Master }]
      foreach intf $intfs {
        set segs [get_bd_addr_segs -addressables -of_objects $intf]
        foreach seg $segs {
          puts "  seg: $seg"
          set sintf [get_bd_intf_pins -quiet -of_objects $seg]
          if {[catch {dict get $map $intf}]} {
            if {[catch {dict get $map $sintf}]} {
              puts "    neither $intf nor $sintf were found in address map for $seg: $::errorInfo"
              puts "    assuming internal connection, setting values as found in segment:"
              set range  [get_property RANGE $seg]
              puts "      range: $range"
              if {$range eq ""} {
                puts "      found no range on segment $seg, skipping"
                report_property $seg
                continue
              }
              set offset [get_property OFFSET $seg]
              if {$offset eq ""} {
                puts "      found no offset on segment $seg, skipping"
                report_property $seg
                continue
              }
              puts "      offset: $offset"
              set me [dict create "range" $range "offset" $offset "space" $space seg "$seg"]
            } else {
              set me [dict get $map $sintf]
            }
          } else {
            set me [dict get $map $intf]
          }
          puts "    address map info: $me]"
          set range  [expr "max([dict get $me range], 4096)"]
          set offset [expr "max([dict get $me "offset"], [get_property OFFSET $intf])"]
          set range  [expr "min($range, [get_property RANGE $intf])"]
          puts "      range: $range"
          puts "      offset: $offset"
          puts "      space: $space"
          puts "      seg: $seg"
          if {[expr "(1 << 64) == $range"]} { set range "16E" }
          create_bd_addr_seg \
            -offset $offset \
            -range $range \
            $space \
            $seg \
            [format "AM_SEG_%03d" $seg_i]
          incr seg_i
        }
      }
    }
  }
}
