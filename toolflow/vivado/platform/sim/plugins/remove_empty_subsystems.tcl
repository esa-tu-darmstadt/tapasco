
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

namespace eval remove_empty_subsystems {

  # remove subsystems memory and intc
  # empty subsystems lead to an error when generating verilog files in vivado for some reason
  proc remove_empty_subsystems {} {
    remove_ss memory
    remove_ss intc
  }

  # remove subsystem with name {name}
  proc remove_ss {name} {
    delete_bd_objs [get_bd_cells $name]
  }

}

tapasco::register_plugin "platform::remove_empty_subsystems::remove_empty_subsystems" "post-platform"
