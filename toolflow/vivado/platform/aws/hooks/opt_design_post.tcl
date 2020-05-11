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

puts "Running opt_design post hook..."

source [file join $::env(HDK_SHELL_DIR) hlx build scripts subscripts apply_debug_constraints_hlx.tcl]

# "This ensures that there are no contentions on clock nets for designs that have large number of clock nets."
# from `hdk/docs/AWS_Shell_V1.4_Migration_Guidelines.md`
set_param hd.clockRoutingWireReduction false

# vim: set expandtab ts=2 sw=2:
