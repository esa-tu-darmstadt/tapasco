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
source -notrace $::env(TAPASCO_HOME_TCL)/platform/zynq/zynq.tcl

namespace eval platform {
  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/pynq/plugins" "*.tcl"] {
    puts "Found plugin: $f"
    source -notrace $f
  }

  proc create_clock_port {{name "sys_clk"}} {
    puts "creating 125 MHz clock port ..."
    set clk [create_bd_port -dir I -type clk $name]
    set_property CONFIG.FREQ_HZ 125000000 $clk
    return $clk
  }
}
