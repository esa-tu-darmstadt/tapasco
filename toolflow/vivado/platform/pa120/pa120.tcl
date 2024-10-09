# Copyright (c) 2014-2024 Embedded Systems and Applications, TU Darmstadt.
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

namespace eval platform {
  set platform_dirname "pa120"
  set pcie_width "16"
  set pcie_speed "16.0"
  set cpm_version "CPM5"

  source $::env(TAPASCO_HOME_TCL)/platform/versal/versal_base.tcl

  proc get_mc_type {} {
    return {LPDDR}
  }

  proc get_number_mc {} {
    return 4
  }

  # MC 0,1,2 even support LPDDR4-3733, but not MC3
  proc get_mc_config {} {
    return [list \
      CONFIG.MC_INPUTCLK0_PERIOD {3333} \
      CONFIG.MC_MEMORY_TIMEPERIOD0 {625} \
      CONFIG.CONTROLLERTYPE {LPDDR4_SDRAM} \
      CONFIG.MC_MEMORY_SPEEDGRADE {LPDDR4-3200} \
      CONFIG.MC_ROWADDRESSWIDTH {16} \
      CONFIG.MC_TFAW {40000} \
      CONFIG.MC_TRRD {10000} \
      CONFIG.MC3_FLIPPED_PINOUT {true} \
      CONFIG.MC_NO_CHANNELS {Dual} \
      CONFIG.MC_WRITE_DM_DBI {DM_NO_DBI}]
  }

  proc get_cips_config {} {
    # Set IO BANK voltages
    return [list \
      CONFIG.PS_PMC_CONFIG { \
        PMC_BANK_0_IO_STANDARD LVCMOS1.8 \
        PMC_BANK_1_IO_STANDARD LVCMOS1.8 \
        PS_BANK_2_IO_STANDARD LVCMOS3.3 \
        PS_BANK_3_IO_STANDARD LVCMOS3.3 \
      } \
    ]
  }

  proc get_mc_clk_freq {} {
    return 300000000
  }

  proc get_total_memory_size {} {
    return [expr "1 << 34"]
  }

  proc add_constraints {args} {
    set constraints_fn "$::env(TAPASCO_HOME_TCL)/platform/pa120/pa120.xdc"
    read_xdc $constraints_fn
    set_property PROCESSING_ORDER EARLY [get_files $constraints_fn]
    return $args
  }

  tapasco::register_plugin "platform::add_constraints" "post-platform"
}
