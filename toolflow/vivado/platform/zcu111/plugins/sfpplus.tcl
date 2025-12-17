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

namespace eval sfpplus {

  proc is_sfpplus_supported {} {
    return true
  }

  proc get_available_modes {} {
    return {"10G"}
  }

  proc num_available_ports {mode} {
    if {$mode == "10G"} {
      return [10g::num_available_ports]
    }
    puts "Invalid SFP+ mode: mode $mode is not supported by this platform. Available modes are: 10G"
    exit
  }

  proc generate_cores {mode ports} {
    if {$mode == "10G"} {
      10g::generate_cores $ports
      save_bd_design
    } else {
      puts "Invalid SFP+ mode: mode $mode is not supported by this platform. Available modes are: 10G"
      exit
    }
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {
      set args [lappend args "M_NETWORK" [list 0x00B0020000 0 0 ""]]
    }
    return $args
  }

}

tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"
