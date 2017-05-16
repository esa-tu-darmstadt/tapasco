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
source -notrace $::env(TAPASCO_HOME)/platform/zynq/zynq.tcl

namespace eval platform {
  namespace export create
  namespace export max_masters

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/zc706/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [zynq::max_masters]
  }

  proc create {} {
    return [zynq::create]
  }
}
