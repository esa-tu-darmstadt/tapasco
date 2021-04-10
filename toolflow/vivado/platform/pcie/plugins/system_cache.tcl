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

namespace eval system_cache {

	proc get_mem_connections {} {
		set subsystem "/memory"
		set instance [current_bd_instance]
		current_bd_instance $subsystem
		set clock [tapasco::subsystem::get_port "mem" "clk"]
		set reset [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]
		current_bd_instance $instance
		return [list [get_bd_intf_pins /memory/mig_ic/M00_AXI] [get_bd_intf_pins -regexp /memory/mig/(C0_DDR4_)?S_AXI] $subsystem $clock $reset]
	}
}
