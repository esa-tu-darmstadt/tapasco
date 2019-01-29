#
# Copyright (C) 2018 Carsten Heinz, TU Darmstadt
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
namespace eval clk2x {
  proc wrap_clk_2x {inst {args}} {
    # check for clk_2x
    set inst [get_bd_cells $inst]
    set clock_ports2x [get_bd_pins -of_objects $inst -filter {DIR == I && (NAME =~ *clk* || NAME =~ *CLK* || NAME =~ clock) && (NAME =~ *2x* || NAME =~ *2X*)}]
    if {[llength $clock_ports2x] > 0} {
      puts "   IP has a 2x clk, will add a PLL"
      set clock_ports [get_bd_pins -of_objects $inst -filter {DIR == I && (NAME =~ *clk* || NAME =~ *CLK* || NAME =~ clock) && NAME !~ *2x* && NAME !~ *2X*}]
      set clock_in [lindex $clock_ports 0]

      set freq [tapasco::get_design_frequency]
      set freq2x [expr $freq*2]
      puts "   Frequency is $freq MHz, doubling to $freq2x MHz"

      # add a PLL
      set pll "clk_2x_pll"

      if {[llength [get_bd_cells $pll]] > 0} {
        puts "     re-use existing pll"
      } else {
        ::tapasco::ip::create_clk_wiz $pll
        set_property -dict [list CONFIG.PRIMITIVE {PLL} CONFIG.USE_LOCKED {false} \
          CONFIG.USE_RESET {false} CONFIG.USE_POWER_DOWN {false} CONFIG.PRIM_SOURCE {Global_buffer} \
          CONFIG.PRIM_IN_FREQ $freq CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $freq2x] \
          [get_bd_cells $pll]
        set_property CONFIG.PRIM_IN_FREQ.VALUE_SRC PROPAGATED [get_bd_cells $pll]
      }
      connect_bd_net [get_bd_pins $pll/clk_out1] $clock_ports2x
    }
    return [list $inst $args]
  }
}

tapasco::register_plugin "arch::clk2x::wrap_clk_2x" "post-pe-create"
