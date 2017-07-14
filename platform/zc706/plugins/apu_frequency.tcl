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
# @file   apu_frequency.tcl
# @brief  Plugin to set APU (ARM core on PS side) frequency to 800 MHz for the
#         ZC706 to override board preset of 667 MHz.
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval apu_frequency {
  proc set_max_apu_frequency {{args {}}} {
    puts "Increasing ZC706 APU frequency to 800 MHz ..."
    set ps [get_bd_cell -hierarchical -filter {VLNV =~ "xilinx.com:ip:processing_system*"}]
    set_property -dict [list CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {800}] $ps
    return {}
  }
}

tapasco::register_plugin "platform::apu_frequency::set_max_apu_frequency" "post-bd"
