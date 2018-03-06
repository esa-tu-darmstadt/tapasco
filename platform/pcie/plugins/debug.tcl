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
  source -notrace "$::env(TAPASCO_HOME)/platform/common/plugins/debug.tcl"

  # override empty debug nets
  proc get_debug_nets {} {
    # TODO define defaults for VC709
    return [list ]
  }
}
