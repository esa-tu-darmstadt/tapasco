# Copyright (c) 2014-2022 Embedded Systems and Applications, TU Darmstadt.
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

namespace eval mrmac {
  proc is_mrmac_supported {} {
    return true
  }

  # @return the number of physical ports available on this platform
  proc num_available_ports {} {
    return 4
  }

  proc get_mrmac_locations {} {
    return {"MRMAC_X0Y0" "MRMAC_X0Y1" "MRMAC_X0Y2" "MRMAC_X0Y3"}
  }

  proc get_refclk_freq {} {
    return 156.25
  }
}
