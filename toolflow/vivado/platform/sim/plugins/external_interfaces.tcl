
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

namespace eval external_connections {

  proc make_external_connections {{args}} {
    ## tapasco subsystem
    puts "external connections start"
    set arch [tapasco::subsystem::get arch]
    set s_arch [get_bd_intf_pins -of_objects $arch -filter {NAME == S_ARCH}]
    make_bd_intf_pins_external $s_arch
    set s_arch_ext [get_bd_intf_ports -filter {NAME == S_ARCH_0}]
    set_property NAME S_ARCH $s_arch_ext
    set ext_design_clk [get_bd_ports -filter {NAME == ext_design_clk}]
    set_property CONFIG.ASSOCIATED_BUSIF {S_ARCH} $ext_design_clk
    puts "external connections end"
    save_bd_design
  }

}

# tapasco::register_plugin "platform::external_connections::make_external_connections" "pre-wiring"
