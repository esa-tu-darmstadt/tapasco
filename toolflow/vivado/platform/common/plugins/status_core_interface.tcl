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

namespace eval status_core_interface {

  proc get_interface_info { vlnv intf } {
    set intf_rename [tapasco::get_feature "IPEC"]
    set intfname [lindex [split $intf /] end]
    if {[dict exists $intf_rename $vlnv $intfname]} {
      set kid [dict get $intf_rename $vlnv $intfname "kid"]
      set kid [expr int($kid)]
      set vlnv [dict get $intf_rename $vlnv $intfname "vlnv"]
      puts "  replaced vlnv $vlnv kid $kid"
      return [list $kid $vlnv]
    }
    return {}
  }

}

tapasco::register_plugin "platform::status_core_interface::get_interface_info" "status-core-interface"
