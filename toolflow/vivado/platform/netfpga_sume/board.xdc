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

#The following two properties should be set for every design
set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]

#PCIe Transceiver clock (100 MHz)
# Note: This clock is attached to a MGTREFCLK pin
set_property -dict { PACKAGE_PIN AB7 } [get_ports { IBUF_DS_N }];
set_property -dict { PACKAGE_PIN AB8 } [get_ports { IBUF_DS_P }];
set_property LOC AY35 [get_ports { pcie_perst }]
set_property IOSTANDARD LVCMOS18    [get_ports { pcie_perst }]
set_property PULLUP true [get_ports { pcie_perst }]
set_false_path -from [get_ports pcie_perst]
create_clock -add -name pcie_clk_pin -period 10.000 -waveform {0 5.000} [get_ports {IBUF_DS_P}];
set_property LOC IBUFDS_GTE2_X1Y11 [get_cells {system_i/host/refclk_ibuf/U0/USE_IBUFDS_GTE2.GEN_IBUFDS_GTE2[0].IBUFDS_GTE2_I}]

# PadFunction: IO_L13P_T2_MRCC_35
set_property VCCAUX_IO DONTCARE [get_ports {sys_clk_clk_p}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {sys_clk_clk_p}]
set_property PACKAGE_PIN E34 [get_ports {sys_clk_clk_p}]

# PadFunction: IO_L13P_T2_MRCC_38
set_property VCCAUX_IO DONTCARE [get_ports {clk_ref_clk_p}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {clk_ref_clk_p}]
set_property PACKAGE_PIN H19 [get_ports {clk_ref_clk_p}]

# reset - Btn0
set_property PACKAGE_PIN AR13 [get_ports sys_rst_0]
set_property IOSTANDARD LVCMOS15 [get_ports sys_rst_0]

# Timing Constraints
create_clock -period 4.288 [get_nets sys_clk_clk_p]
#set_propagated_clock sys_clk_clk_p

create_clock -period 5 [get_nets clk_ref_clk_p]
#set_propagated_clock clk_ref_clk_p

set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sys_clk_clk_p]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_pins -hierarchical *pll*CLKIN1]

# Note: CLK_REF FALSE Constraint
set_property CLOCK_DEDICATED_ROUTE FALSE [get_pins -hierarchical *clk_ref_mmcm_gen.mmcm_i*CLKIN1]
