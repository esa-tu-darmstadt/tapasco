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

	proc create_system_cache {} {
		if {[tapasco::is_feature_enabled "Cache"]} {
			set instance [current_bd_instance]
			set cf [tapasco::get_feature "Cache"]
			puts "Platform configured w/L2 Cache, implementing ..."
			set i 0
			foreach {platform_port memory_port subsystem clock reset} [get_mem_connections] {
				puts "  Inserting cache between $platform_port and $memory_port in subsystem $subsystem"
				current_bd_instance $subsystem
				set cache [tapasco::ip::create_axi_cache "cache_l2_$i" 1 \
				  [tapasco::get_feature_option "Cache" "size" 32768] \
				  [tapasco::get_feature_option "Cache" "associativity" 2]]
				if {[get_property CONFIG.DATA_WIDTH $platform_port] > 32} {
					# set slave port width to 512bit, otherwise uses (not working) width conversion in SmartConnect
					set_property CONFIG.C_S0_AXI_GEN_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $platform_port] $cache
				}
				if {[tapasco::get_feature_option "Cache" "force_allocate_read"]} {
					# force caching for master (otherwise relies on axi cache signals)
					puts "  Force allocate read"
					set_property CONFIG.C_S0_AXI_GEN_FORCE_READ_ALLOCATE 1 $cache
					set_property CONFIG.C_S0_AXI_GEN_FORCE_READ_BUFFER 1 $cache
				}
				if {[tapasco::get_feature_option "Cache" "force_allocate_write"]} {
					puts "  Force allocate write"
					set_property CONFIG.C_S0_AXI_GEN_FORCE_WRITE_ALLOCATE 1 $cache
					set_property CONFIG.C_S0_AXI_GEN_FORCE_WRITE_BUFFER 1 $cache
				}

				# remove existing connection
				delete_bd_objs [get_bd_intf_nets -of_objects $memory_port]
				# connect mig_ic master to cache_l2
				connect_bd_intf_net $platform_port [get_bd_intf_pins $cache/S0_AXI_GEN]
				# connect cache_l2 to MIG
				connect_bd_intf_net [get_bd_intf_pins $cache/M0_AXI] $memory_port

				# connect clocks and reset
				connect_bd_net $clock [get_bd_pins $cache/ACLK]
				connect_bd_net $reset [get_bd_pins $cache/ARESETN]
				incr i
			}
			current_bd_instance $instance
		}
		return {}
	}

	proc get_mem_connections {} {
		error "Cache feature not implemented for this platform"
	}
}

tapasco::register_plugin "platform::system_cache::create_system_cache" "post-platform"

