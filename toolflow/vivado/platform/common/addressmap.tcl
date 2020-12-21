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

namespace eval addressmap {
  namespace export add_platform_component
  namespace export add_processing_element
  namespace export get_platform_component_bases
  namespace export get_processing_element_bases
  namespace export reset

  set platform_components [dict create]
  set processing_elements [dict create]

  proc reset {} {
    variable processing_elements
    set processing_elements [dict create]
  }

  proc add_platform_component {name base size} {
    variable platform_components
    puts "Adding platform component $name at [format "0x%08x" $base] ..."
    if {[dict exists $platform_components $name]} {
      puts "WARNING: platform component $name already exists, overwriting!"
    }
    dict set platform_components $name $base $size
  }

  proc get_platform_component_bases {} {
    variable platform_components
    set ret [list]
    dict for {c comp} $platform_components {
      set comp_addr [lindex $comp 0]
      set size [lindex $comp 1]
      lappend ret $c $comp_addr $size
    }
    puts "Platform component bases: $ret"
    return $ret
  }

  proc add_processing_element {slot base size} {
    variable processing_elements
    puts "Adding processing element in slot $slot with base [format "0x%08x" $base] and size $size ..."
    if {[dict exists $processing_elements $slot]} {
      puts "WARNING: processing element in slot $slot already exists, overwriting!"
    }
    dict set processing_elements $slot $base $size
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
    set max_slot [lindex [lsort -integer -decreasing [dict keys $processing_elements]] 0]
    set ret [list]
    for {set i 0} {$i <= $max_slot} {incr i} {
      lappend ret [get_processing_element $i]
    }
    return $ret
  }

  proc increase_component_name {component} {
    if {[regexp {(.*)(\d+)} $component _ prefix suffix]} {
      incr suffix
      return [format "%s%d" $prefix $suffix]
    }
    return $component
  }

  proc assign_address {address_map master base {stride 0} {range 0} {component ""}} {
    foreach seg [lsort [get_bd_addr_segs -addressables -of_objects $master]] {
      puts [format "  $master: $seg -> 0x%08x (range: 0x%08x)" $base $range]
      set sintf [get_bd_intf_pins -of_objects $seg]
      set srange $range
      if {$range <= 0} { set srange [get_property RANGE $seg] }
      set kind [get_property USAGE $seg]
      dict set address_map $sintf "interface $sintf offset $base range $srange kind $kind"
      if {[string compare $component ""] != 0} {
        add_platform_component $component $base $srange
        set component [increase_component_name $component]
      }
      if {$stride == 0} { incr base $srange } else { incr base $stride }
    }
    return $address_map
  }

  proc apply_address_map_mods {map} {
    foreach p [lsort [info commands ::platform::modify_address_map_*]] {
      puts "  found address map extension proc: $p"
      set map [eval {$p} {$map}]
    }
    return $map
  }

  proc construct_address_map {{map ""}} {
    if {$map == ""} { set map [::platform::get_address_map [::platform::get_pe_base_address]] }
    set map [apply_address_map_mods $map]
    set ignored [::platform::get_ignored_segments]
    set seg_i 0
    foreach space [get_bd_addr_spaces] {
      puts "space: $space"
      set intfs [get_bd_intf_pins -quiet -of_objects $space -filter { MODE == Master }]
      foreach intf $intfs {
        set segs [get_bd_addr_segs -addressables -of_objects $intf]
        foreach seg $segs {
          if {[lsearch $ignored $seg] >= 0 } {
            puts "Skipping ignored segment $seg"
          } else {
            puts "  seg: $seg"
            set sintf [get_bd_intf_pins -quiet -of_objects $seg]
            if {[catch {dict get $map $intf}]} {
              if {[catch {dict get $map $sintf}]} {
                puts "    neither $intf nor $sintf were found in address map for $seg: $::errorInfo"
                puts "    assuming internal connection, setting values as found in segment:"
                set range  [get_property RANGE $seg]
                if {$range eq ""} {
                  puts "      found no range on segment $seg, setting to max"
                  report_property $seg
                  set range [expr "1 << 64"]
                }
                puts "      range: $range"
                set offset [get_property OFFSET $seg]
                if {$offset eq ""} {
                  puts "      found no offset on segment $seg, setting to zero"
                  report_property $seg
                  set offset 0
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
            if {[get_property NAME $seg] == "DmiDebugMem"} {
                puts "      Found Riscv Debug Memory"
                set pe_id [scan [regsub {.*target_ip_.*([0-9][0-9][0-9])} $seg {\1}] %d]
                ::tapasco::ip::add_debug_to_pe $pe_id "RiscvDebug" \
                    [expr $offset - [::platform::get_pe_base_address]] $range
            }
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
}
