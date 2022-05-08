#!/bin/bash
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

sed -i 's/set_property supported_families .*$/set_property supported_families [list zynq Pre-Production virtex7 Pre-Production kintex7 Pre-Production artix7 Pre-Production zynquplus Pre-Production virtex7 Pre-Production qvirtex7 Pre-Production kintex7 Pre-Production kintex7l Pre-Production qkintex7 Pre-Production qkintex7l Pre-Production artix7 Pre-Production artix7l Pre-Production aartix7 Pre-Production qartix7 Pre-Production zynq Pre-Production qzynq Pre-Production azynq Pre-Production spartan7 Pre-Production virtexu Pre-Production virtexuplus Pre-Production virtexuplushbm Pre-Production kintexuplus Pre-Production zynquplus Pre-Production kintexu Pre-Production versal Pre-Production] $core/g' run_ippack.tcl
sed -i 's/\(set DisplayName.*\)$/\1\nset IPName $DisplayName/g' run_ippack.tcl
