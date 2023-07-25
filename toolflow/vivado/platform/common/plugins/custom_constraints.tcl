# Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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

namespace eval custom_constraints {

  proc parse_constraints_file {} {
    if {[tapasco::is_feature_enabled "CustomConstraints"]} {
      set config [tapasco::get_feature "CustomConstraints"]
      dict with config {
        set file [file normalize $path]
        if {![file exists $file]} {
          puts "CustomConstraints: file $file does not exist"
          exit 1
        }
        set constraints_file "[get_property DIRECTORY [current_project]]/[file tail $file]"
        file copy -force $file $constraints_file
        read_xdc $constraints_file
        set_property PROCESSING_ORDER LATE [get_files $constraints_file]
      }
    }
  }
}

tapasco::register_plugin "platform::custom_constraints::parse_constraints_file" "pre-arch"
