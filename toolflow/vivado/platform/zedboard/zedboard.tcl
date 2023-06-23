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

source -notrace $::env(TAPASCO_HOME_TCL)/platform/zynq/zynq.tcl

namespace eval ::platform {

  if { [::tapasco::vivado_is_newer "2021.1"] == 1 } {
    puts "Vivado [version -short] is too new to support zedboard."
    exit 1
  }

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/zedboard/plugins" "*.tcl"] {
    puts "Found plugin: $f"
    source -notrace $f
  }
}
