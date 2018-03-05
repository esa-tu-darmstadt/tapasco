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
# @file		subsystem.tcl
# @brief	Subsystem block creation helpers.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
#
namespace eval subsystem {
  namespace export create
  namespace export get_port
  namespace export get_ports
  namespace export get_names
  namespace export get_custom_names
  namespace export get_all
  namespace export get

  # Creates a hierarchical cell with given name and interface ports for clocks
  # and resets of the three base clocks in TaPaSCo designs.
  # @param is_source if true, will create output ports, otherwise input ports
  proc create {name {is_source false}} {
    set instance [current_bd_instance]
    set cell [create_bd_cell -type hier $name]
    current_bd_instance $cell
    set d [expr "{$is_source} ? {O} : {I}"]

    foreach c {host design mem} {
      set clk   [create_bd_pin -type clk -dir $d "${c}_clk"]
      set prstn [create_bd_pin -type rst -dir $d "${c}_peripheral_aresetn"]
      set prst  [create_bd_pin -type rst -dir $d "${c}_peripheral_areset"]
      set irstn [create_bd_pin -type rst -dir $d "${c}_interconnect_aresetn"]
    }

    current_bd_instance $instance
    return $cell
  }

  proc get_ports {} {
    set d [dict create]
    foreach c {host design mem} {
      set clk   [get_bd_pins -of_objects [current_bd_instance .] -filter "NAME == ${c}_clk"]
      set prstn [get_bd_pins -of_objects [current_bd_instance .] -filter "NAME == ${c}_peripheral_aresetn && TYPE == rst"]
      set prst  [get_bd_pins -of_objects [current_bd_instance .] -filter "NAME == ${c}_peripheral_areset && TYPE == rst"]
      set irstn [get_bd_pins -of_objects [current_bd_instance .] -filter "NAME == ${c}_interconnect_aresetn && TYPE == rst"]
      dict set d $c "clk" $clk
      dict set d $c "rst" "peripheral" "resetn" $prstn
      dict set d $c "rst" "peripheral" "reset" $prst
      dict set d $c "rst" "interconnect" $irstn
    }
    return $d
  }

  # Returns pin of given type on the sub-block interface of the current instance.
  proc get_port {args} {
    if {[catch {dict get [get_ports] {*}$args} err]} {
      puts "ERROR: $err $::errorInfo"
      error "get_port: invalid args $args"
    }
    set r [dict get [get_ports] {*}$args]
    if {[llength $r] == 0 || [llength $r] > 1} {
      catch {error "get_port: incomplete args $args"}
      puts "get_ports: [get_ports]"
      error "$::errorInfo"
    }
    return $r
  }

  # Returns the names of custom subsystems on this Platform.
  proc get_custom {} {
    set names [list]
    foreach n [info commands ::platform::create_custom_subsystem_*] {
      lappend names [regsub {.*create_custom_subsystem_(.*)} $n {\1}]
    }
    return $names
  }

  proc get_names {} {
    set names [list "arch"]
    foreach n [info commands ::platform::create_subsystem_*] {
      set name [regsub {.*create_subsystem_(.*)} $n {\1}]
      lappend names $name
    }
    return [concat $names [get_custom]]
  }

  proc get_all {} {
    set cells [dict create]
    foreach name [get_names] { dict set cells $name [get_bd_cells "/$name"] }
    return $cells
  }

  proc get {name} {
    set all [get_all]
    if {![dict exists $all $name]} { error "subsystem $name does not exist!" }
    return [dict get [get_all] $name]
  }
}
