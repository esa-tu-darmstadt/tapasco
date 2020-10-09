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

# Constraints for left HBM stack

set_property PACKAGE_PIN BJ43 [get_ports hbm_ref_clk_clk_p]
set_property PACKAGE_PIN BJ44 [get_ports hbm_ref_clk_clk_n]
set_property IOSTANDARD LVDS [get_ports hbm_ref_clk_clk_p]
set_property IOSTANDARD LVDS [get_ports hbm_ref_clk_clk_n]
set_property DQS_BIAS TRUE [get_ports hbm_ref_clk_clk_p]

create_clock -period 10 -name sysclk0 [get_ports hbm_ref_clk_clk_p]

set_clock_groups -asynchronous -group [get_clocks hbm_ref_clk_clk_p -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out1_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out2_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out3_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out4_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out5_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out6_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out7_system_clk_wiz_0 -include_generated_clocks]


set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets system_i/hbm/clocking_0/ibuf/U0/IBUF_OUT[0]]