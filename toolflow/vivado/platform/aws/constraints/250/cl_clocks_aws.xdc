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

# Group A Clocks
create_clock -period 4  -name clk_main_a0 -waveform {0.000 2}  [get_ports clk_main_a0]
create_clock -period 8 -name clk_extra_a1 -waveform {0.000 4} [get_ports clk_extra_a1]
create_clock -period 2.667 -name clk_extra_a2 -waveform {0.000 1.333} [get_ports clk_extra_a2]
create_clock -period 2 -name clk_extra_a3 -waveform {0.000 1} [get_ports clk_extra_a3]

# Group B Clocks
create_clock -period 2.222 -name clk_extra_b0 -waveform {0.000 1.111} [get_ports clk_extra_b0]
create_clock -period 4.444 -name clk_extra_b1 -waveform {0.000 2.222} [get_ports clk_extra_b1]

# Group C Clocks
create_clock -period 6.667 -name clk_extra_c0 -waveform {0.000 3.333} [get_ports clk_extra_c0]
create_clock -period 5 -name clk_extra_c1 -waveform {0.000 2.5} [get_ports clk_extra_c1]
