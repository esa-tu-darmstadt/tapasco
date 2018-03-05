#
# Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
# @file   debug.tcl
# @brief  Plugin to add ILA cores to the design. GP0, HP0, HP2 and ACP are
#         addded by default; other nets can be added as strings via feature.
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval ::platform::debug {
  namespace export debug_feature
  namespace export get_debug_nets
  namespace export write_ltx

  # This function should be overridden in Platform implementations with sensible
  # default patterns for useful nets.
  proc get_debug_nets {} {}

  proc debug_feature {} {
    if {[tapasco::is_feature_enabled "Debug"]} {
      # get config
      set debug [tapasco::get_feature "Debug"]
      # default values
      set depth        4096
      set stages       0
      set use_defaults false
      set nets         {}
      if {[dict exists $debug "depth"]} { set depth [dict get $debug "depth"] }
      if {[dict exists $debug "stages"]} { set stages [dict get $debug "stages"] }
      if {[dict exists $debug "use_defaults"]} { set use_defaults [dict get $debug "use_defaults"] }
      if {[dict exists $debug "nets"]} { set nets [dict get $debug "nets"] }
      if {[llength $nets] > 0) {
        puts "Creating ILA debug core, will require re-run of synthesis."
        puts "  Debug = $debug"
        set dnl {}
        if {$use_defaults} { foreach n [get_debug_nets] { lappend dnl $n }}
        if {[llength $nets] > 0} {
          foreach n $nets {
            set nnets [get_nets $n]
            puts "  for '$n' found [llength $nnets] nets: $nnets"
            foreach nn $nnets { lappend dnl [list $nn] }
          }
        }
        # create ILA core
        set clk [lindex [get_nets system_i/* -filter {NAME =~ *clocks_and_resets_*clk}] 0]
        puts "  clk = $clk"
        tapasco::create_debug_core $clk $dnl $depth $stages
        reset_run synth_1
      }
    }
    return {}
  }

  proc write_ltx {} {
    global bitstreamname
    if {[tapasco::is_feature_enabled "Debug"]} {
      puts "Writing debug probes into file ${bitstreamname}.ltx ..."
      write_debug_probes -force -verbose "${bitstreamname}.ltx"
    }
    return {}
  }
}

tapasco::register_plugin "platform::debug::debug_feature" "post-synth"
tapasco::register_plugin "platform::debug::write_ltx" "post-impl"
