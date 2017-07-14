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
namespace eval debug {
  namespace export debug_feature

  proc get_debug_nets {} {
    puts "Adding default signals to the ILA core ..."
    set ret [list [get_nets -hier "*irq_out*"]]
    set defsignals [list \
      "_RDATA*" \
      "_WDATA*" \
      "_ARADDR*" \
      "_AWADDR*" \
      "_AWVALID" \
      "_AWREADY" \
      "_ARVALID" \
      "_ARREADY" \
      "_WVALID" \
      "_WREADY" \
      "_WSTRB*" \
      "_RVALID" \
      "_RREADY" \
      "_ARBURST*" \
      "_AWBURST*" \
      "_ARLEN*" \
      "_AWLEN*" \
      "_WLAST" \
      "_RLAST" \
    ]
    foreach m [arch::get_masters] {
      set name [get_property NAME $m]
      foreach s $defsignals {
        set net [get_nets -hier "*$name$s"]
        puts "  adding net $net for signal $s ..."
        if {[llength $net] > 1} { lappend ret $net } { lappend ret [list $net] }
      }
    }
    foreach m {"system_i/Host_M_AXI_GP0"} {
      foreach s $defsignals {
        set net [get_nets "$m$s"]
        puts "  adding net $net for signal $s ..."
        if {[llength $net] > 1} { lappend ret $net} { lappend ret [list $net] }
      }
    }
    puts "  signal list: $ret"
    return $ret
  }

  proc debug_feature {} {
    if {[tapasco::is_platform_feature_enabled "Debug"]} {
      puts "Creating ILA debug core, will require re-run of synthesis."
      # get config
      set debug [tapasco::get_platform_feature "Debug"]
      puts "  Debug = $debug"
      # default values
      set depth        4096
      set stages       0
      set use_defaults true
      set nets         {}
      if {[dict exists $debug "depth"]} { set depth [dict get $debug "depth"] }
      if {[dict exists $debug "stages"]} { set stages [dict get $debug "stages"] }
      if {[dict exists $debug "use_defaults"]} { set use_defaults [dict get $debug "use_defaults"] }
      if {[dict exists $debug "nets"]} { set nets [dict get $debug "nets"] }
      set dnl {}
      if {$use_defaults} { foreach n [get_debug_nets] { lappend dnl $n }}
      if {[llength $nets] > 0} {
        foreach n $nets {
          set nnets [get_nets -hier $n]
          puts "  for '$n' found [llength $nnets] nets: $nnets"
          foreach nn $nnets { lappend dnl [list $nn] }
        }
      }
      # create ILA core
      tapasco::create_debug_core [get_nets system_i/Host_fclk0_aclk] $dnl $depth $stages
      reset_run synth
    }
    return {}
  }

  proc write_ltx {} {
    global bitstreamname
    if {[tapasco::is_platform_feature_enabled "Debug"]} {
      puts "Writing debug probes into file ${bitstreamname}.ltx ..."
      write_debug_probes -force -verbose "${bitstreamname}.ltx"
    }
    return {}
  }
}

tapasco::register_plugin "platform::zynq::debug::debug_feature" "post-synth"
tapasco::register_plugin "platform::zynq::debug::write_ltx" "post-impl"
