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

puts "Running opt_design pre hook..."

add_files [file join $::env(HDK_SHELL_DIR) build checkpoints from_aws SH_CL_BB_routed.dcp]

add_files [file join $::env(FAAS_CL_DIR) build checkpoints CL.post_synth.dcp]

set_property SCOPED_TO_CELLS {WRAPPER_INST/CL} [get_files [file join $::env(FAAS_CL_DIR) build checkpoints CL.post_synth.dcp]]

read_xdc [file join $::env(HDK_SHELL_DIR) build constraints cl_ddr.xdc]

read_xdc $::env(PNR_USER)
set_property PROCESSING_ORDER LATE [get_files $::env(PNR_USER)]
set_property USED_IN {implementation} [get_files $::env(PNR_USER)]

link_design -top top_sp -part [get_parts -of_objects [current_project]] \
  -reconfig_partitions {WRAPPER_INST/SH WRAPPER_INST/CL}

set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets WRAPPER_INST/SH/kernel_clks_i/clkwiz_sys_clk/inst/CLK_CORE_DRP_I/clk_inst/clk_out2]
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets WRAPPER_INST/SH/kernel_clks_i/clkwiz_sys_clk/inst/CLK_CORE_DRP_I/clk_inst/clk_out3]

source [file join $::env(TAPASCO_HOME_TCL) platform aws constraints 250 aws_gen_clk_constraints.tcl]

source [file join $::env(HDK_SHELL_DIR) build scripts check_uram.tcl]

# vim: set expandtab ts=2 sw=2:
