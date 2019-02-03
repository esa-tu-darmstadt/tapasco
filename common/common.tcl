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
# @file		common.tcl
# @brief	Common Vivado Tcl helper procs to create block designs.
# @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval tapasco {

  namespace export vivado_is_newer
  namespace export is_hls
  # Returns true if the vivado version running is newer or equal to the desired one
  # @param Desired Vivado Version as String, e.g. "2018.3"
  # @return 1 if [version -short] <= cmp, else 0
  proc vivado_is_newer {cmp} {
    set regex {([0-9][0-9][0-9][0-9]).([0-9][0-9]*)}
    set major_ver [regsub $regex [version -short] {\1}]
    set minor_ver [regsub $regex [version -short] {\2}]
    set major_cmp [regsub $regex $cmp {\1}]
    set minor_cmp [regsub $regex $cmp {\2}]
    if { ($major_ver > $major_cmp) || (($major_ver == $major_cmp) && ($minor_ver >= $minor_cmp)) } {
      return 1
    } else {
      return 0
    }
  }

  # Returns true if Vivado HLS is running
  # @return 1 if HLS, else 0
  proc is_hls {} {
    if {[string first "HLS" [version] ]} {
      return 1
    } else {
      return 0
    }
  }

  namespace export source_quiet
  proc source_quiet {fn} {
    # Vivado HLS lost -notrace for whatever reason in Vivado HLS 2018.3
    if {[is_hls] == 1 && [vivado_is_newer "2018.2"] == 1} {
      eval "source " $fn
    } else {
      eval "source " $fn "[expr {[string is space [info commands version]] ? {} : {-notrace}}]"
    }
  }

  source_quiet $::env(TAPASCO_HOME)/common/subsystem.tcl
  source_quiet $::env(TAPASCO_HOME)/common/ip.tcl

  namespace export get_board_preset
  namespace export get_composition
  namespace export get_design_frequency
  namespace export get_design_period
  namespace export get_number_of_processors
  namespace export get_speed_grade
  namespace export get_wns_from_timing_report
  namespace export get_capabilities_flags
  namespace export set_capabilities_flags
  namespace export add_capabilities_flag

  namespace export create_interconnect_tree

  # Returns the Tapasco version.
  proc get_tapasco_version {} {
    return "2018.2"
  }

  # Returns the interface pin groups for all AXI MM interfaces on cell.
  # @param cell the object whose interfaces shall be returned
  # @parma mode filters interfaces by mode (default: Master)
  # @return list of interface pins
  proc get_aximm_interfaces {cell {mode "Master"}} {
    return [get_bd_intf_pins -of_objects $cell -filter "VLNV =~ xilinx.com:interface:aximm_rtl:* && MODE == $mode"]
  }

  # Returns the given property of a given AXI MM interface.
  # Will raise an error, if none or conflicting values are found.
  # @param name of property
  # @param intf interface pin to get property for
  # @return value of property
  proc get_aximm_property {property intf} {
    set dw [get_property $property $intf]
    if {$dw == {}} {
      set nets [get_bd_intf_nets -hierarchical -boundary_type lower -of_objects $intf]
      set srcs [get_bd_intf_pins -of_objects $nets -filter "$property != {}"]
      if {[llength $srcs] == 0} {
        error "ERROR: could not find a connected interface pin where $property is set"
      } else {
        set dws {}
        foreach s $srcs { lappend dws [get_property $property $s] }
        if {[llength $dws] > 1} {
          error "ERROR: found conflicting values for $property @ $intf: $dws"
        }
        return [lindex $dws 0]
      }
    } else {
      return $dw
    }
  }

  # Returns a key-value list of frequencies in the design.
  proc get_frequencies {} {
    return [list "host" [get_host_frequency] "design" [get_design_frequency] "memory" [get_mem_frequency]]
  }

  # Returns the host interface clock frequency (in MHz).
  proc get_host_frequency {} {
    global tapasco_host_freq
    if {[info exists tapasco_host_freq]} {
      return $tapasco_host_freq
    } else {
      puts "WARNING: tapasco_host_freq is not set, using design frequency of [tapasco::get_design_frequency] MHz"
      return [tapasco::get_design_frequency]
    }
  }

  # Returns the memory interface clock frequency (in MHz).
  proc get_mem_frequency {} {
    global tapasco_mem_freq
    if {[info exists tapasco_mem_freq]} {
      return $tapasco_mem_freq
    } else {
      puts "WARNING: tapasco_mem_freq is not set, using design frequency of [tapasco::get_design_frequency] MHz"
      return [tapasco::get_design_frequency]
    }
  }

  # Returns the desired design clock frequency (in MHz) selected by the user.
  # Default: 50 MHz
  proc get_design_frequency {} {
    global tapasco_freq
    if {[info exists tapasco_freq]} {
      return $tapasco_freq
    } else {
      error "ERROR: tapasco_freq is not set!"
    }
  }

  # Returns the desired design clock period (in ns) selected by the user.
  # Default: 4
  proc get_design_period {} {
    return [expr "1000 / [get_design_frequency]"]
  }

  # Returns the board preset selected by the user.
  # Default: ZC706
  proc get_board_preset {} {
    global tapasco_board_preset
    if {[info exists tapasco_board_preset]} {return $tapasco_board_preset} {return {}}
  }

  # Returns an array of lists consisting of VLNV and instance count of kernels in
  # the current composition.
  proc get_composition {} {
    global kernels
    return $kernels
  }

  # Returns a list of configured features.
  proc get_features {} {
    global features
    if {[info exists features]} { return [dict keys $features] } { return [dict create] }
  }

  # Returns a dictionary with the configuration of given feature (if it exists).
  proc get_feature {feature} {
    global features
    if {[info exists features]} { return [dict get $features $feature] } { return [dict create] }
  }

  # Returns true, if given feature is configured and enabled.
  proc is_feature_enabled {feature} {
    global features
    if {[info exists features]} {
      if {[dict exists $features $feature]} {
        if {[dict get $features $feature "enabled"] == "true"} {
          return true
        }
      }
    }
    return false
  }

  proc create_debug_core {clk nets {depth 4096} {stages 0} {name "u_ila_0"}} {
    puts "Creating an ILA debug core ..."
    puts "  data depth      : $depth"
    puts "  pipeline stages : $stages"
    puts "  clock           : $clk"
    puts "  number of probes: [llength $nets]"
    set dc [::create_debug_core $name ila]
    set_property C_DATA_DEPTH $depth $dc
    set_property C_TRIGIN_EN false $dc
    set_property C_TRIGOUT_EN false $dc
    set_property C_INPUT_PIPE_STAGES $stages $dc
    set_property ALL_PROBE_SAME_MU true $dc
    set_property ALL_PROBE_SAME_MU_CNT 1 $dc
    set_property C_EN_STRG_QUAL 0 $dc
    set_property C_ADV_TRIGGER 0 $dc
    set_property ALL_PROBE_SAME_MU true $dc
    # connect clock
    set_property port_width 1 [get_debug_ports $dc/clk]
    connect_debug_port u_ila_0/clk [get_nets $clk]
    set i 0
    foreach n $nets {
      puts "  current nl: $n"
      if {$i > 0} { create_debug_port $dc probe }
      set_property port_width [llength $n] [get_debug_ports $dc/probe$i]
      connect_debug_port $dc/probe$i $n
      incr i
    }
    set xdc_file "[get_property DIRECTORY [current_project]]/debug.xdc"
    puts "  xdc_file = $xdc_file"
    close [ open $xdc_file w ]
    add_files -fileset [current_fileset -constrset] $xdc_file
    set_property target_constrs_file $xdc_file [current_fileset -constrset]
    save_constraints -force
    return $dc
  }

  # Creates a tree of AXI interconnects to accomodate n connections.
  # @param name Name of the group cell
  # @param n Number of connnections (outside)
  # @param masters if true, will create n master connections, otherwise slaves
  proc create_interconnect_tree {name n {masters true}} {
    puts "Creating AXI Interconnect tree $name for $n [expr $masters ? {"masters"} : {"slaves"}]"
    puts "  tree depth: [expr int(ceil(log($n) / log(16)))]"
    puts "  instance : [current_bd_instance .]"

    # create group
    set instance [current_bd_instance .]
    set group [create_bd_cell -type hier $name]
    current_bd_instance $group

    # create hierarchical ports: clocks, resets (interconnect + peripherals)
    set m_aclk [create_bd_pin -type "clk" -dir "I" "m_aclk"]
    set m_ic_arstn [create_bd_pin -type "rst" -dir "I" "m_interconnect_aresetn"]
    set m_p_arstn [create_bd_pin -type "rst" -dir "I" "m_peripheral_aresetn"]
    set s_aclk [create_bd_pin -type "clk" -dir "I" "s_aclk"]
    set s_ic_arstn [create_bd_pin -type "rst" -dir "I" "s_interconnect_aresetn"]
    set s_p_arstn [create_bd_pin -type "rst" -dir "I" "s_peripheral_aresetn"]

    set ic_n 0
    set ics [list]
    set ns [list]
    set totalOut $n

    puts "  totalOut = $totalOut"
    if {$masters} {
      # all interconnects except the outermost slaves are driven by the master clock
      set main_aclk $m_aclk
      set main_p_arstn $m_p_arstn
      set main_ic_arstn $m_ic_arstn
      # the slave clock is only used for the last stage
      set scnd_aclk $s_aclk
      set scnd_p_arstn $s_p_arstn
      set scnd_ic_arstn $s_ic_arstn
    } {
      # all interconnects except the outermost masters are driven by the slave clock
      set main_aclk $s_aclk
      set main_p_arstn $s_p_arstn
      set main_ic_arstn $s_ic_arstn
      # the master clock is only used for the last stage
      set scnd_aclk $m_aclk
      set scnd_p_arstn $m_p_arstn
      set scnd_ic_arstn $m_ic_arstn
    }

    # special case: bypass (not necessary; only for performance, Tcl is slow)
    if {$totalOut == 1} {
      puts "  building 1-on-1 bypass"
      set bic [ip::create_axi_ic "bic" 1 1]
      set m [create_bd_intf_pin -mode Master -vlnv "xilinx.com:interface:aximm_rtl:1.0" "M000_AXI"]
      set s [create_bd_intf_pin -mode Slave -vlnv "xilinx.com:interface:aximm_rtl:1.0" "S000_AXI"]
      connect_bd_intf_net $s [get_bd_intf_pins -filter {VLNV == "xilinx.com:interface:aximm_rtl:1.0" && MODE == "Slave"} -of_objects $bic]
      connect_bd_intf_net [get_bd_intf_pins -filter {VLNV == "xilinx.com:interface:aximm_rtl:1.0" && MODE == "Master"} -of_objects $bic] $m

      connect_bd_net $m_aclk [get_bd_pins -filter {NAME =~ "M*_ACLK"} -of_objects $bic]
      connect_bd_net $s_aclk [get_bd_pins -filter {NAME =~ "S*_ACLK"} -of_objects $bic]
      connect_bd_net $m_p_arstn [get_bd_pins -filter {NAME =~ "M*_ARESETN"} -of_objects $bic]
      connect_bd_net $s_p_arstn [get_bd_pins -filter {NAME =~ "S*_ARESETN"} -of_objects $bic]
      connect_bd_net $main_aclk [get_bd_pins -filter {NAME == "ACLK"} -of_objects $bic]
      connect_bd_net $main_ic_arstn [get_bd_pins -filter {NAME == "ARESETN"} -of_objects $bic]
      current_bd_instance $instance
      return $group
    }

    # pre-compute ports at each stage
    while {$n != 1} {
      lappend ns $n
      set n [expr "int(ceil($n / 16.0))"]
    }
    if {!$masters} { set ns [lreverse $ns] }
    puts "  ports at each stage: $ns"

    # keep track of the interconnects at each stage
    set stage [list]

    # loop over nest levels
    foreach n $ns {
      puts "  generating stage $n ($ns) ..."
      set nports $n
      set n [expr "int(ceil($n / 16.0))"]
      set curr_ics [list]
      #puts "n = $n"
      for {set i 0} {$i < $n} {incr i} {
        set rest_ports [expr "$nports - $i * 16"]
        set rest_ports [expr "min($rest_ports, 16)"]
        set nic [ip::create_axi_ic [format "ic_%03d" $ic_n] [expr "$masters ? $rest_ports : 1"] [expr "$masters ? 1 : $rest_ports"]]
        incr ic_n
        lappend curr_ics $nic
      }

      # on first level only: connect slaves to outside
      if {[llength $ics] == 0} {
        set pidx 0
        set ss [lsort [get_bd_intf_pins -filter {VLNV == "xilinx.com:interface:aximm_rtl:1.0" && MODE == "Slave"} -of_objects $curr_ics]]
        foreach s $ss {
          lappend ics [create_bd_intf_pin -mode Slave -vlnv "xilinx.com:interface:aximm_rtl:1.0" [format "S%03d_AXI" $pidx]]
          incr pidx
        }
        set ms $ics
      } {
        # in between: connect masters from previous level to slaves of current level
        set ms [lsort [get_bd_intf_pins -filter {VLNV == "xilinx.com:interface:aximm_rtl:1.0" && MODE == "Master"} -of_objects $ics]]
      }

      # masters/slaves from previous level
      set ss [lsort [get_bd_intf_pins -filter {VLNV == "xilinx.com:interface:aximm_rtl:1.0" && MODE == "Slave"} -of_objects $curr_ics]]
      set idx 0
      foreach m $ms {
        if {$masters} {
          connect_bd_intf_net $m [lindex $ss $idx]
        } {
          connect_bd_intf_net [lindex $ss $idx] $m
        }
        incr idx
      }

      # on last level only: connect master port to outside
      if {[expr "($masters && $n == 1) || (!$masters &&  $nports == $totalOut)"]} {
        # connect outputs
        set ms [lsort [get_bd_intf_pins -filter {VLNV == "xilinx.com:interface:aximm_rtl:1.0" && MODE == "Master"} -of_objects $curr_ics]]
        set pidx 0
        foreach m $ms {
          set port [create_bd_intf_pin -mode Master -vlnv "xilinx.com:interface:aximm_rtl:1.0" [format "M%03d_AXI" $pidx]]
          connect_bd_intf_net $m $port
          incr pidx
        }
      }
      set ics $curr_ics
      # record current stage
      lappend stage $curr_ics
    }

    # connect stage-0 slave clks to outer slave clock
    if {$masters} {
      # last stage is "right-most" stage
      set main_range [lrange $stage 1 end]
      set last_stage [lindex $stage 0]
    } {
      # last stage is "left-most" stage
      set main_range [lrange $stage 0 end-1]
      set last_stage [lrange $stage end end]
    }
    # bulk connect clocks and resets of all interconnects except on the last stage to main clock
    foreach icl $main_range {
      puts "  current stage list: $icl"
      # connect all clocks to master clock
      connect_bd_net $main_aclk [get_bd_pins -filter {TYPE == "clk" && DIR == "I"} -of_objects $icl]
      # connect all m/s resets to master peripheral reset
      connect_bd_net $main_p_arstn [get_bd_pins -filter {TYPE == "rst" && DIR == "I" && NAME != "ARESETN"} -of_objects $icl]
    }
    # last stage requires separate connections
    puts "  last stage: $last_stage"
    if {$masters} {
      # connect all non-slave clocks to main clock, and only slave clocks to secondary clock
      connect_bd_net $main_aclk [get_bd_pins -filter {TYPE == "clk" && DIR == "I" && NAME !~ "S*_ACLK"} -of_objects $last_stage]
      connect_bd_net $scnd_aclk [get_bd_pins -filter {TYPE == "clk" && DIR == "I" && NAME =~ "S*_ACLK"} -of_objects $last_stage]
    } {
      # connect all non-master clocks to main clock, and only master clocks to secondary clock
      connect_bd_net $main_aclk [get_bd_pins -filter {TYPE == "clk" && DIR == "I" && NAME !~ "M*_ACLK"} -of_objects $last_stage]
      connect_bd_net $scnd_aclk [get_bd_pins -filter {TYPE == "clk" && DIR == "I" && NAME =~ "M*_ACLK"} -of_objects $last_stage]
    }
    # now connect all resets
    connect_bd_net $main_ic_arstn [get_bd_pins -filter {TYPE == "rst" && DIR == "I" && NAME == "ARESETN"} -of_objects [get_bd_cells "$group/*"]]
    connect_bd_net $m_p_arstn [get_bd_pins -filter {TYPE == "rst" && DIR == "I" && NAME =~ "M*_ARESETN"} -of_objects $last_stage]
    connect_bd_net $s_p_arstn [get_bd_pins -filter {TYPE == "rst" && DIR == "I" && NAME =~ "S*_ARESETN"} -of_objects $last_stage]

    current_bd_instance $instance
    return $group
  }

  set plugins [dict create]

  proc register_plugin {call when} {
    variable plugins
    puts "Registering new plugin call '$call' to be called at event '$when' ..."
    dict lappend plugins $when $call
  }

  proc get_plugins {when} {
    variable plugins
    if {[dict exists $plugins $when]} { return [dict get $plugins $when] } { return [list] }
  }

  proc call_plugins {when args} {
    variable plugins
    puts "Calling $when plugins ..."
    if {[dict exists $plugins $when]} {
      set calls [dict get $plugins $when]
      if {[llength $calls] > 0} {
        puts "  found [llength $calls] plugin calls at $when"
        foreach cb $calls {
          puts "  calling $cb $args ..."
          set args [eval $cb $args]
        }
      }
    }
    puts "Event $when finished."
    return $args
  }

  # Returns the number of processors in the system.
  proc get_number_of_processors {} {
    global tapasco_jobs
    if {![info exists tapasco_jobs] && ![catch {open "/proc/cpuinfo"} f]} {
      set tapasco_jobs [regexp -all -line {^processor\s} [read $f]]
      close $f
      if {$tapasco_jobs <= 0} { set tapasco_jobs 1 }
    }
    return $tapasco_jobs
  }

  # Parses a Vivado timing report and report the worst negative slack (WNS) value.
  # @param reportfile Filename of timing report
  proc get_wns_from_timing_report {reportfile} {
    set f [open $reportfile r]
    set tr [read $f]
    close $f
    if {[regexp {\s*WNS[^\n]*\n[^\n]*\n\s*(-?\d+\.\d+)} $tr line wns] > 0} {
      return $wns
    } {
      return 0
    }
  }

  # Returns the speed grade of the FPGA part in the current design.
  proc get_speed_grade {} {
    return [get_property SPEED [get_parts [get_property PART [current_project]]]]
  }

  set capabilities_0 0

  # Returns the value of the CAPABILITIES_0 bitfield as currently configured.
  proc get_capabilities_flags {} {
    variable capabilities_0
    return $capabilities_0
  }

  # Sets the value of the CAPABILITIES_0 bitfield.
  proc set_capabilities_flags {flags} {
    variable capabilities_0
    puts [format "Setting Capability bitfield to new value 0x%08x (%d)." $flags $flags]
    set capabilities_0 $flags
  }

  # Adds a specific bit to the CAPABILITIES_0 bitfield.
  proc add_capabilities_flag {bit} {
    variable capabilities_0
    if {[string is integer $bit]} {
      if {$bit < 0 || $bit > 31} { error "Invalid bit index: $bit" }
      set flag [expr "(1 << $bit)"]
    } else {
      set caps_file [open "$::env(TAPASCO_HOME)/platform/include/platform_caps.h" "r"]
      set caps_cnts [split [read $caps_file] "\n"]
      close $caps_file

      set caps [dict create]
      foreach line $caps_cnts {
        if {[regexp {(PLATFORM_CAP[^\s]*)\s*=\s*([^,]+)\s*,} $line _ n v]} {
          dict set caps $n [expr $v]
        }
      }

      if {[dict exists $caps $bit]} {
        set flag [dict get $caps $bit]
        puts "  matched $bit to value $v, adding ..."
      } else {
        error "ERROR: unknown capability flag: $bit - known caps: [dict keys $caps]"
      }
    }
    set flags [get_capabilities_flags]
    set nflags [expr "$flags | $flag"]
    puts [format "Adding bit $flag to capability bitfield: 0x%08x (%d) -> 0x%08x (%d)." $flags $flags $nflags $nflags]
    set capabilities_0 $nflags
  }

  proc get_platform_num_slots {} {
    set f [open "$::env(TAPASCO_HOME)/platform/include/platform_global.h" "r"]
    set fl [split [read $f] "\n"]
    foreach line $fl {
      if {[regexp {define\s*PLATFORM_NUM_SLOTS\s*(\d+)} $line _ ret]} {
        return $ret
      }
    }
  }
}
