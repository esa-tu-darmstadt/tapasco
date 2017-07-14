#
# Copyright (C) 2017 Jens Korinth, TU Darmstadt
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
# @file		platform.tcl
# @brief	Platform skeleton implementations.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
#
namespace eval platform {
  namespace export generate

  # Checks all current runs at given step for errors, outputs their log files in case.
  # @param synthesis Checks synthesis runs if true, implementation runs otherwise.
  proc check_run_errors {{synthesis true}} {
    if {$synthesis} {
      set failed_runs [get_runs -filter "IS_SYNTHESIS == 1 && PROGRESS != {100%}"]
    } else {
      set failed_runs [get_runs -filter "IS_IMPLEMENTATION == 1 && PROGRESS != {100%}"]
    }
    # check number of failed runs
    if {[llength $failed_runs] > 0} {
      puts "at least one run failed, check these logs for errors:"
      foreach r $failed_runs {
        puts "  [get_property DIRECTORY $r]/runme.log"
      }
      exit 1
    }
  }

  # Platform API: Main entry point to generate the bitstream.
  proc generate {} {
    global bitstreamname
    # generate bitstream from given design and report utilization / timing closure
    set jobs [tapasco::get_number_of_processors]
    puts "  using $jobs parallel jobs"

    generate_target all [get_files system.bd]
    set synth_run [get_runs synth_1]
    set_property -dict [list \
      strategy Flow_PerfOptimized_high \
      STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AlternateRoutability \
      STEPS.SYNTH_DESIGN.ARGS.RETIMING true \
    ] $synth_run
    current_run $synth_run
    launch_runs -jobs $jobs $synth_run
    wait_on_run $synth_run
    if {[get_property PROGRESS $synth_run] != {100%}} { check_run_errors true }
    open_run $synth_run

    # call plugins
    tapasco::call_plugins "post-synth"

    set impl_run [get_runs impl_1]
    set_property -dict [list \
      STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore \
      STEPS.PHYS_OPT_DESIGN.IS_ENABLED true \
    ] $impl_run
    current_run $impl_run
    launch_runs -jobs $jobs -to_step route_design $impl_run
    wait_on_run $impl_run
    if {[get_property PROGRESS $impl_run] != {100%}} { check_run_errors false }
    open_run $impl_run

    # call plugins
    tapasco::call_plugins "post-impl"

    if {[get_property PROGRESS [get_runs $impl_run]] != "100%"} {
      error "ERROR: impl failed!"
    }
    report_timing_summary -warn_on_violation -file timing.txt
    report_utilization -file utilization.txt
    report_utilization -file utilization_userlogic.txt -cells [get_cells -hierarchical -filter {NAME =~ *target_ip_*}]
    report_power -file power.txt
    set wns [tapasco::get_wns_from_timing_report "timing.txt"]
    if {$wns >= -0.3} {
      write_bitstream -force "${bitstreamname}.bit"
    } else {
      error "timing failure, WNS: $wns"
    }
  }
}
