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

##### Internal configuration format #####
#   A dictionary containg the parsed configuration
#   The dictionary maps port names to the configured properties of the port:
#    - physical_port: number of the physical port it should be connected to
#    - ic_sync: if true, AXIS Interconnects are added to synchronize between the SFP+- and PE- clocks; otherwise synchronization must be handled by the PE
#    - mode: one of singular, roundrobin and broadcast; determines how PEs are connected to the port
#    - name: name of the port
#    - reciever_list: a list of AXI-Stream Slaves which will be connected to the port
#    - sender_list: a list of AXI-Stream Masters which will be connected to the port

##### Physical Port configuration #####
#   A dictionary mapping physical ports to the port_name
#   The physical ports are represented by a number from 0 to num_available_ports() (exclusive)
#   Contains only entries for the physical ports which should be used in the design

if {[tapasco::is_feature_enabled "SFPPLUS"]} {
  proc create_custom_subsystem_network {{args {}}} {

    set ports [sfpplus::parse_configuration false]
    set port_names [dict keys $ports]

    set physical_ports [sfpplus::get_physical_port_dict $ports]

    sfpplus::create_network_pins $port_names
    # START platform specific
    puts "Creating Network Interfaces for Ports: $port_names"
    sfpplus::generate_cores [sfpplus::parse_mode] $physical_ports 
    # END platform specific

    sfpplus::connect_ports $ports
    puts "Network Connection done"
      
  }
}

namespace eval sfpplus {

  ###### START PLATFORM SPECIFIC ######

  # To add SFP+-Support for a new platform, create a new plugin file for the platform.
  # In the plugin file you need to source this file and overwrite these four functions.

  # Overwrite this function with "return true" to enable SPF+ for a new platform
  # @return whether SFP+ is supported on this platform
  proc is_sfpplus_supported {} {
    return false
  }

  # @return the number of physical ports available on this platform
  proc num_available_ports {mode} {
    return 0
  }

  # @return a list of the available modes for this platform. the first item is the default mode
  proc get_available_modes {} {
    return {}
  }

  # Generate the required platform specific IP to use the SFP+Ports.
  # The following pins must be connected appropriately for each port with name port_name:
  #  - AXIS_RX_port_name: the AXI Stream for the recieved packets of the port
  #  - AXIS_TX_port_name: the AXI Stream for sending packets on the port
  #  - sfp_rx_clock_port_name: the clock for recieving stream
  #  - sfp_tx_clock_port_name: the clock for the sending stream
  #  - sfp_rx_resetn_port_name: the reset for the recieving stream
  #  - sfp_tx_resetn_port_name: the reset for the sending stream
  # @param physical_ports a dictionary mapping physical ports to the port_name. See Physical Port configuration at the top of this file
  proc generate_cores {mode physical_ports} {

  }

  ###### END PLATFORM SPECIFIC ######


  ###### START PARSE CONFIGURATION ######

  # Retrieves the configured mode from the JSON configuration
  # @return the configured mode; if no mode is given the default for this platform
  proc parse_mode {} {
    variable config [tapasco::get_feature "SFPPLUS"]
    dict with config {
      if {![info exists mode]} {
        set mode [lindex [get_available_modes] 0]
      }
      return $mode
    }
  }

  # Parses the JSON configuration
  # @param true if currently in the phase of validating the configuration
  # @return a dictionary containing the parsed configuration. See Internal configuration format at the top of this file
  proc parse_configuration {validation} {
    variable config [tapasco::get_feature "SFPPLUS"]
    dict with config {
      set available_PEs [build_pe_dict $validation]

      foreach port $ports {
        dict with port {
          dict set available_ports $name $port
          dict set available_ports $name sender_list [list]
          dict set available_ports $name reciever_list [list]
        }
      }

      foreach b $pes {
        dict with b {
          if {![dict exists $available_PEs $ID]} {
            puts "Invalid SFP+ Configuration: No PE of type $ID in your composition."
            exit
          }

          set pe_list [dict get $available_PEs $ID]
          if {[llength $pe_list] < $Count} {
            puts "Invalid SFP+ Configuration: More PEs of type $ID used than specified in your composition."
            exit
          }
          set selected [lrange $pe_list 0 $Count-1]
          set new_list [lrange $pe_list $Count end]
          dict set available_PEs $ID $new_list

          foreach PE $selected {
            foreach mapping $mappings {
              dict with mapping {

                if {![dict exists $available_ports $port]} {
                  puts "Invalid SFP+ Configuration: Port $port not specified"
                  exit
                }

                switch $direction {
                  tx   {
                    set sender_list [dict get $available_ports $port sender_list]
                    set new_sender_list [lappend sender_list "$PE/$interface"]
                    dict set available_ports $port sender_list $new_sender_list
                  }
                  rx  {
                    set reciever_list [dict get $available_ports $port reciever_list]
                    set new_reciever_list [lappend reciever_list "$PE/$interface"]
                    dict set available_ports $port reciever_list $new_reciever_list
                  }
                  default {
                    puts "Invalid SFP+ Configuration: direction must be either 'tx' or 'rx', is $direction"
                    exit
                  }
                }
              }
            }
          }
        }
      }
      return $available_ports
    }
  }

  # Build a dictionary containing all PEs in the composition
  # @param true if currently in the phase of validating the configuration
  # @return a dictionary mapping types (of PEs) to a list containing all PEs of that type in the current composition
  proc build_pe_dict {validation} {
    set composition [tapasco::get_composition]
    for {set i 0} {$i < [llength $composition]} {incr i 2} {
      set PEs [lindex $composition [expr $i + 1]]
      set comp_index [lindex $composition $i]
      dict with PEs {
        regexp {.*:.*:(.*):.*} $vlnv -> ip
        if {$validation} {
          dict set available_PEs $ip [lrepeat $count $ip]
        } else {
          dict set available_PEs $ip [get_bd_cells -filter "NAME =~ *target_ip_[format %02d $comp_index]_* && TYPE == ip" -of_objects [get_bd_cells /arch]]
        }
      }
    }
    return $available_PEs
  }

  # Extract the physical port configuration from the internal configuration
  # @param ports Interal configuration format; see top of this file
  # @return Physical Port configuration; see top of this file
  proc get_physical_port_dict {ports} {
    foreach key [dict keys $ports] {
      set port [dict get $ports $key]
      dict with port {
        dict set physical_ports $physical_port $name
      }
    }
    return $physical_ports
  }

  ###### END PARSE CONFIGURATION ######


  ###### START VALIDATE CONFIGURATION ######

  # Validates the SFP+ configuration provided by the user
  proc validate_sfp_ports {} {
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {

      if {![is_sfpplus_supported]} {
        puts "SFP+ not supported on this platform"
        exit
      }
      set ports [parse_configuration true]
      set num_ports [dict size $ports]
      set available_ports [num_available_ports [parse_mode]]
      if { $num_ports > $available_ports} {
        puts "Invalid SFP+ Configuration: Too many SFP-Ports specified (Max: $available_ports)"
        exit
      }
      set port_numbers [list]
      foreach key [dict keys $ports] {
        set port [dict get $ports $key]
        dict with port {
          if {$physical_port < 0 || $physical_port >= $available_ports} {
            puts "Invalid SFP+ Configuration: Physical port $physical_port is outside allowed range on this platform (allowed 0 - [expr $available_ports - 1])"
            exit
          }
          if {[lsearch $port_numbers $physical_port] >= 0} {
            puts "Invalid SFP+ Configuration: Physical port $physical_port defined multiple times"
            exit
          }
          lappend port_numbers $physical_port
          switch $mode {
            singular   {
              set min 1
              set max 1
            }
            broadcast  {
              set min 2
              set max 16
            }
            roundrobin {
              set min 2
              set max 16
            }
            default {
              puts "Invalid SFP+ Configuration: Mode $mode not supported"
              exit
            }
          }
          check_range $sender_list $min $max $mode senders $name
          check_range $reciever_list $min $max $mode recievers $name
        }
      }
    }
  }

  # Check whether the length of the list is in the range given by the min and max value (both inclusive)
  proc check_range {list min max mode type port_name} {
    if {[llength $list] < $min} {
      puts "Invalid SFP+ Configuration: In $mode mode each port must have at least $min $type. Port $port_name has [llength $list] $type"
      exit
    }
    if {[llength $list] > $max} {
      puts "Invalid SFP+ Configuration: In $mode mode each port max have only $max $type. Port $port_name has [llength $list] $type"
      exit
    }
  }

  ###### END VALIDATE CONFIGURATION ######

  # Create the pins in the network subsystem which will be connected by the platform-specific part
  # @param ports a list of port names
  proc create_network_pins {ports} {
    for {set i 0} {$i < [llength $ports]} {incr i} {
      set port [lindex $ports $i]
      # Local Pins (Network-Hierarchie)
      create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_RX_${port}
      create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_TX_${port}
      create_bd_pin -type clk -dir O sfp_tx_clock_${port}
      create_bd_pin -type rst -dir O sfp_tx_resetn_${port}
      create_bd_pin -type clk -dir O sfp_rx_clock_${port}
      create_bd_pin -type rst -dir O sfp_rx_resetn_${port}
    }
  }

  # Connect the given ports to the PEs as specified
  # @param ports Internal configuration format; see top of file
  proc connect_ports {ports} {
    foreach key [dict keys $ports] {
      set port [dict get $ports $key]
      dict with port {
        set num_sender [llength $sender_list]
        set num_reciever [llength $reciever_list]
        puts "Creating Port $name"
        puts "  with mode -> $mode"
        puts "  with ic_sync -> $ic_sync"
        puts "  with $num_reciever reciever"
        puts "  with $num_sender sender"
        connect_port $name $mode $reciever_list $sender_list $ic_sync
      }
    }
  }

  # Connect one port to PEs as specified
  # @param name the name of the port
  # @param mode one of singular, roundrobin or broadcast
  # @param reciever_list a list of AXIS Slaves recieving packets from the port
  # @param sender_list a list of AXIS Masters sending packets via the port
  # @param ic_sync if true, AXIS Interconnects are added to synchronize between the SFP+- and PE- clocks; otherwise synchronization must be handled by the PE
  proc connect_port {name mode reciever_list sender_list ic_sync} {
    current_bd_instance /arch
    create_bd_pin -type clk -dir I sfp_tx_clock_${name}
    create_bd_pin -type rst -dir I sfp_tx_resetn_${name}
    create_bd_pin -type clk -dir I sfp_rx_clock_${name}
    create_bd_pin -type rst -dir I sfp_rx_resetn_${name}

    create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_RX_${name}
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_TX_${name}

    set num_reciever [llength $reciever_list]
    set num_sender [llength $sender_list]

    # Create bd cells which provide the AXI streams for the PEs
    set port_in [create_reciever_cell $name $num_reciever]
    set port_out [create_transmitter_cell $name $num_sender]

    # Fill the bd cells depending on the mode
    switch $mode {
      singular   {
        generate_singular $ic_sync $port_in $port_out
      }
      broadcast  {
        generate_broadcast $ic_sync $num_reciever $num_sender $port_in $port_out
      }
      roundrobin {
        generate_roundrobin $ic_sync $num_reciever $num_sender $port_in $port_out
      }
    }

    # Connect PEs
    connect_recievers $reciever_list $port_in $name $ic_sync
    connect_senders $sender_list $port_out $name $ic_sync

    current_bd_instance /network
  }

  # Generate hierarchical structure for a reciever cell which handles the connection betweeen the recieving AXI-Stream of one port
  # and the connected PEs (depending on the mode selected for the port)
  # @param port_name the name of the port
  # @param num_reciever the number AXIS-Interfaces which will be connected to the port
  # @return the bd cell
  proc create_reciever_cell {port_name num_reciever} {
    set cell [create_bd_cell -type hier SFP_${port_name}_reciever]
    set current [current_bd_instance .]
    current_bd_instance $cell

    create_cell_pins $port_name rx

    create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_RX
    for {variable i 0} {$i < $num_reciever} {incr i} {
      create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M[format %02d $i]_AXIS
    }
    connect_bd_intf_net [get_bd_intf_pins /arch/AXIS_RX_${port_name}] [get_bd_intf_pins AXIS_RX]

    current_bd_instance $current
    return $cell
  }

  # Generate hierarchical structure for a transmitter cell which handles the connection betweeen the sending AXI-Stream of one port
  # and the connected PEs (depending on the mode selected for the port)
  # @param port_name the name of the port
  # @param num_sender the number AXIS-Interfaces which will be connected to the port
  # @return the bd cell
  proc create_transmitter_cell {port_name num_sender} {
    set cell [create_bd_cell -type hier SFP_${port_name}_transmitter]
    set current [current_bd_instance .]
    current_bd_instance $cell

    create_cell_pins $port_name tx
    
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_TX
    for {variable i 0} {$i < $num_sender} {incr i} {
      create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S[format %02d $i]_AXIS
    }
    connect_bd_intf_net [get_bd_intf_pins /arch/AXIS_TX_${port_name}] [get_bd_intf_pins AXIS_TX]

    current_bd_instance $current
    return $cell
  }

  # Create the pins for a reciever or transmitter cell
  # @param port_name the name of the port
  # @param direction 'rx' for reciever; 'tx' for transmitter
  proc create_cell_pins {port_name direction} {
    create_bd_pin -dir I design_clk
    create_bd_pin -dir I design_interconnect_aresetn
    create_bd_pin -dir I design_peripheral_aresetn
    create_bd_pin -dir I design_peripheral_areset
    create_bd_pin -dir I sfp_${direction}_clock
    create_bd_pin -dir I sfp_${direction}_resetn

    connect_bd_net [get_bd_pins sfp_${direction}_clock]  [get_bd_pins /arch/sfp_${direction}_clock_${port_name}]
    connect_bd_net [get_bd_pins sfp_${direction}_resetn] [get_bd_pins /arch/sfp_${direction}_resetn_${port_name}]
    connect_bd_net [get_bd_pins design_clk] [get_bd_pins /arch/design_clk]
    connect_bd_net [get_bd_pins design_peripheral_aresetn]     [get_bd_pins /arch/design_peripheral_aresetn]
    connect_bd_net [get_bd_pins design_peripheral_areset]      [get_bd_pins /arch/design_peripheral_areset]
    connect_bd_net [get_bd_pins design_interconnect_aresetn]   [get_bd_pins /arch/design_interconnect_aresetn]
  }

  # Connect interfaces to a port as recievers
  # @param interface_list the AXIS Slave interfaces
  # @param port_in the bd cell providing the streams for the interfaces
  # @param port_name the name of the port
  # @param ic_sync if true, AXIS Interconnects are added to synchronize between the SFP+- and PE- clocks; otherwise synchronization must be handled by the PE
  proc connect_recievers {interface_list reciever_cell port_name ic_sync} {
    for {variable i 0} {$i < [llength $interface_list]} {incr i} {
      set interface [lindex $interface_list $i]
      puts "Connecting reciever $interface to Port $port_name"
      connect_bd_intf_net [get_bd_intf_pins $reciever_cell/M[format %02d $i]_AXIS] [get_bd_intf_pins $interface]

      if {!$ic_sync} {
        connect_clock_pe_sync $interface $reciever_cell rx
      }
    }
  }

  # Connect interfaces to a port as senders
  # @param interface_list the AXIS Slave interfaces
  # @param port_in the bd cell providing the streams for the interfaces
  # @param port_name the name of the port
  # @param ic_sync if true, AXIS Interconnects are added to synchronize between the SFP+- and PE- clocks; otherwise synchronization must be handled by the PE
  proc connect_senders {interface_list transmitter_cell port_name ic_sync} {
    for {variable i 0} {$i < [llength $interface_list]} {incr i} {
      set interface [lindex $interface_list $i]
      puts "Connecting sender $interface to Port $port_name"
      connect_bd_intf_net [get_bd_intf_pins $transmitter_cell/S[format %02d $i]_AXIS] [get_bd_intf_pins $interface]

      if {!$ic_sync} {
        connect_clock_pe_sync $interface $transmitter_cell tx
      }
    }
  }

  ######## START GENERATE FOR MODES ########

  # Fill reciever and transmitter cell for a port in singular mode
  # @param ic_sync true if clock synchronization should be handled by interconnects
  # @param reciever_cell the reciever cell for this port
  # @param transmitter_cell the transmitter cell for this port
  proc generate_singular {ic_sync reciever_cell transmitter_cell} {
    if {$ic_sync} {
      set current [current_bd_instance .]
      current_bd_instance $reciever_cell

      # IC synchronization -> add interconnects

      # Create Interconnect for reciever synchronization
      set sync_ic_in [tapasco::ip::create_axis_ic reciever_sync 1 1]
      set_property -dict [list CONFIG.S00_FIFO_DEPTH {2048} CONFIG.M00_FIFO_DEPTH {2048} CONFIG.S00_FIFO_MODE {0} CONFIG.M00_FIFO_MODE {0}] $sync_ic_in
      connect_bd_net [get_bd_pins sfp_rx_clock]  [get_bd_pins $sync_ic_in/ACLK] [get_bd_pins $sync_ic_in/S*_ACLK]
      connect_bd_net [get_bd_pins sfp_rx_resetn] [get_bd_pins $sync_ic_in/ARESETN] [get_bd_pins $sync_ic_in/S*_ARESETN]
      connect_bd_net [get_bd_pins design_clk] [get_bd_pins $sync_ic_in/M*_ACLK]
      connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $sync_ic_in/M*_ARESETN]
      connect_bd_intf_net [get_bd_intf_pins $sync_ic_in/S00_AXIS] [get_bd_intf_pins AXIS_RX]
      connect_bd_intf_net [get_bd_intf_pins $sync_ic_in/M00_AXIS] [get_bd_intf_pins M00_AXIS]

      current_bd_instance $transmitter_cell
      # Create Interconnect for transmitter synchronization
      set sync_ic_out [tapasco::ip::create_axis_ic transmitter_sync 1 1]
      set_property -dict [list CONFIG.ARB_ON_TLAST {1} CONFIG.M00_FIFO_DEPTH {4096} CONFIG.S00_FIFO_DEPTH {4096} CONFIG.S00_FIFO_MODE {1} CONFIG.M00_FIFO_MODE {1}] $sync_ic_out
      connect_bd_net [get_bd_pins design_clk]  [get_bd_pins $sync_ic_out/ACLK] [get_bd_pins $sync_ic_out/S*_ACLK]
      connect_bd_net [get_bd_pins design_interconnect_aresetn] [get_bd_pins $sync_ic_out/ARESETN]
      connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $sync_ic_out/S*_ARESETN]
      connect_bd_net [get_bd_pins sfp_tx_clock] [get_bd_pins $sync_ic_out/M*_ACLK]
      connect_bd_net [get_bd_pins sfp_tx_resetn] [get_bd_pins $sync_ic_out/M*_ARESETN]
      connect_bd_intf_net [get_bd_intf_pins $sync_ic_out/M00_AXIS] [get_bd_intf_pins AXIS_TX]
      connect_bd_intf_net [get_bd_intf_pins $sync_ic_out/S00_AXIS] [get_bd_intf_pins S00_AXIS]

      current_bd_instance $current
    } else {
      # PE synchronization -> connect directly
      connect_bd_intf_net [get_bd_intf_pins $reciever_cell/AXIS_RX] [get_bd_intf_pins $reciever_cell/M00_AXIS]
      connect_bd_intf_net [get_bd_intf_pins $transmitter_cell/S00_AXIS] [get_bd_intf_pins $transmitter_cell/AXIS_TX]
    }
  }

  # Fill reciever and transmitter cell for a port in broadcast mode
  # @param ic_sync true if clock synchronization should be handled by interconnects
  # @param num_reciever the number of recieving AXIS-Interfaces
  # @param num_sender the number of sending AXIS-Interfaces
  # @param reciever_cell the reciever cell for this port
  # @param transmitter_cell the transmitter cell for this port
  proc generate_broadcast {ic_sync num_reciever num_sender reciever_cell transmitter_cell} {
    set current [current_bd_instance .]
    current_bd_instance $reciever_cell

    # Create AXIS Broadcast
    set broadcast [tapasco::ip::create_axis_broadcast broadcast]
    set_property CONFIG.NUM_MI $num_reciever $broadcast
    set_property -dict [list CONFIG.M_TDATA_NUM_BYTES {8} CONFIG.S_TDATA_NUM_BYTES {8}] $broadcast

    for {variable i 0} {$i < $num_reciever} {incr i} {
        set_property CONFIG.M[format "%02d" $i]_TDATA_REMAP tdata[63:0] $broadcast
    }

    if {$ic_sync} {
      # IC synchronization -> add interconnect
      connect_bd_net [get_bd_pins design_clk] [get_bd_pins $broadcast/aclk]
      connect_bd_net [get_bd_pins design_interconnect_aresetn] [get_bd_pins $broadcast/aresetn]

      set reciever_sync [tapasco::ip::create_axis_ic reciever_sync 1 1]
      set_property -dict [list CONFIG.S00_FIFO_DEPTH {2048} CONFIG.M00_FIFO_DEPTH {2048} CONFIG.S00_FIFO_MODE {0} CONFIG.M00_FIFO_MODE {0}] $reciever_sync
      connect_bd_net [get_bd_pins sfp_rx_clock]  [get_bd_pins $reciever_sync/ACLK] [get_bd_pins $reciever_sync/S*_ACLK]
      connect_bd_net [get_bd_pins sfp_rx_resetn] [get_bd_pins $reciever_sync/ARESETN] [get_bd_pins $reciever_sync/S*_ARESETN]
      connect_bd_net [get_bd_pins design_clk] [get_bd_pins $reciever_sync/M*_ACLK]
      connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $reciever_sync/M*_ARESETN]

      connect_bd_intf_net [get_bd_intf_pins $broadcast/S_AXIS] [get_bd_intf_pins $reciever_sync/M*_AXIS]
      connect_bd_intf_net [get_bd_intf_pins $reciever_sync/S00_AXIS] [get_bd_intf_pins AXIS_RX]
    } else {
      # PE synchronization -> no additional interconnect necessary
      connect_bd_intf_net [get_bd_intf_pins $broadcast/S_AXIS] [get_bd_intf_pins AXIS_RX]
      connect_bd_net [get_bd_pins sfp_rx_clock] [get_bd_pins $broadcast/aclk]
      connect_bd_net [get_bd_pins sfp_rx_resetn] [get_bd_pins $broadcast/aresetn]
    }

    for {variable i 0} {$i < $num_reciever} {incr i} {
      connect_bd_intf_net [get_bd_intf_pins $broadcast/M[format "%02d" $i]_AXIS] [get_bd_intf_pins M[format "%02d" $i]_AXIS]
    }


    # Create Transmitter Interconnect to bundle AXI-Streams
    current_bd_instance $transmitter_cell
    set transmitter [tapasco::ip::create_axis_ic transmitter $num_sender 1]
    set_property -dict [list CONFIG.ARB_ON_TLAST {1}] $transmitter
    set_property -dict [list CONFIG.M00_FIFO_MODE {1} CONFIG.M00_FIFO_DEPTH {2048}] $transmitter


    for {variable i 0} {$i < $num_sender} {incr i} {
        set_property CONFIG.[format "S%02d" $i]_FIFO_DEPTH 2048 $transmitter
        set_property CONFIG.[format "S%02d" $i]_FIFO_MODE 0 $transmitter
    }
    set_property -dict [list CONFIG.ARB_ALGORITHM {3} CONFIG.ARB_ON_MAX_XFERS {0}] $transmitter

    connect_bd_intf_net [get_bd_intf_pins $transmitter/M*_AXIS] [get_bd_intf_pins AXIS_TX]
    connect_bd_net [get_bd_pins sfp_tx_clock] [get_bd_pins $transmitter/M*_ACLK]
    connect_bd_net [get_bd_pins sfp_tx_resetn] [get_bd_pins $transmitter/M*_ARESETN]

    # Connect clocks of interconnect based on synchronization mode
    if {$ic_sync} {
      connect_bd_net [get_bd_pins design_clk] [get_bd_pins $transmitter/ACLK] [get_bd_pins $transmitter/S*_ACLK]
      connect_bd_net [get_bd_pins design_interconnect_aresetn] [get_bd_pins $transmitter/ARESETN]
      connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $transmitter/S*_ARESETN]
    } else {
      connect_bd_net [get_bd_pins sfp_tx_clock] [get_bd_pins $transmitter/ACLK] [get_bd_pins $transmitter/S*_ACLK]
      connect_bd_net [get_bd_pins sfp_tx_resetn] [get_bd_pins $transmitter/ARESETN] [get_bd_pins $transmitter/S*_ARESETN]
    }

    for {variable i 0} {$i < $num_sender} {incr i} {
      connect_bd_intf_net [get_bd_intf_pins $transmitter/S[format "%02d" $i]_AXIS] [get_bd_intf_pins S[format "%02d" $i]_AXIS]
    }

    current_bd_instance $current
  }

  # Fill reciever and transmitter cell for a port in roundrobin mode
  # @param ic_sync true if clock synchronization should be handled by interconnects
  # @param num_reciever the number of recieving AXIS-Interfaces
  # @param num_sender the number of sending AXIS-Interfaces
  # @param reciever_cell the reciever cell for this port
  # @param transmitter_cell the transmitter cell for this port
  proc generate_roundrobin {ic_sync num_reciever num_sender reciever_cell transmitter_cell} {
    set current [current_bd_instance .]
    current_bd_instance $reciever_cell

    # Create Reciever Interconnect
    set reciever [tapasco::ip::create_axis_ic reciever 1 $num_reciever]
    set_property -dict [list CONFIG.S00_FIFO_MODE {0} CONFIG.S00_FIFO_DEPTH {2048}] $reciever

    for {variable i 0} {$i < $num_reciever} {incr i} {
        set_property CONFIG.[format "M%02d" $i]_FIFO_DEPTH 2048 $reciever
        set_property CONFIG.[format "M%02d" $i]_FIFO_MODE 0 $reciever
    }

    connect_bd_net [get_bd_pins sfp_rx_clock] [get_bd_pins $reciever/ACLK] [get_bd_pins $reciever/S*_ACLK]
    connect_bd_net [get_bd_pins sfp_rx_resetn] [get_bd_pins $reciever/ARESETN] [get_bd_pins $reciever/S*_ARESETN]

    # Connect clocks of interconnect based on synchronization mode
    if {$ic_sync} {
      connect_bd_net [get_bd_pins design_clk] [get_bd_pins $reciever/M*_ACLK]
      connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $reciever/M*_ARESETN]
    } else {
      connect_bd_net [get_bd_pins sfp_rx_clock] [get_bd_pins $reciever/M*_ACLK]
      connect_bd_net [get_bd_pins sfp_rx_resetn] [get_bd_pins $reciever/M*_ARESETN]
    }

    # Create Arbiter which dictates next reciever
    set arbiter [tapasco::ip::create_axis_arbiter arbiter]
    set turnover [tapasco::ip::create_constant roundrobin_turnover 5 $num_reciever]

    connect_bd_net [get_bd_pins $arbiter/maxClients] [get_bd_pins $turnover/dout]
    connect_bd_net [get_bd_pins $arbiter/CLK] [get_bd_pins sfp_rx_clock]
    connect_bd_net [get_bd_pins $arbiter/RST_N] [get_bd_pins sfp_rx_resetn]
    connect_bd_intf_net [get_bd_intf_pins $arbiter/axis_S] [get_bd_intf_pins AXIS_RX]
    connect_bd_intf_net [get_bd_intf_pins $arbiter/axis_M] [get_bd_intf_pins $reciever/S*_AXIS]

    for {variable i 0} {$i < $num_reciever} {incr i} {
      connect_bd_intf_net [get_bd_intf_pins $reciever/M[format "%02d" $i]_AXIS] [get_bd_intf_pins M[format "%02d" $i]_AXIS]
    }

    # Create Transmitter Interconnect
    current_bd_instance $transmitter_cell
    set transmitter [tapasco::ip::create_axis_ic transmitter $num_sender 1]
    set_property -dict [list CONFIG.ARB_ON_TLAST {1}] $transmitter
    set_property -dict [list CONFIG.M00_FIFO_MODE {1} CONFIG.M00_FIFO_DEPTH {2048}] $transmitter


    for {variable i 0} {$i < $num_sender} {incr i} {
      set_property CONFIG.[format "S%02d" $i]_FIFO_DEPTH 2048 $transmitter
      set_property CONFIG.[format "S%02d" $i]_FIFO_MODE 0 $transmitter
    }
    set_property -dict [list CONFIG.ARB_ALGORITHM {3} CONFIG.ARB_ON_MAX_XFERS {0}] $transmitter

    connect_bd_intf_net [get_bd_intf_pins $transmitter/M*_AXIS] [get_bd_intf_pins AXIS_TX]
    connect_bd_net [get_bd_pins sfp_tx_clock] [get_bd_pins $transmitter/M*_ACLK]
    connect_bd_net [get_bd_pins sfp_tx_resetn] [get_bd_pins $transmitter/M*_ARESETN]
    # Connect clocks of interconnect based on synchronization mode
    if {$ic_sync} {
      connect_bd_net [get_bd_pins design_clk] [get_bd_pins $transmitter/ACLK] [get_bd_pins $transmitter/S*_ACLK]
      connect_bd_net [get_bd_pins design_interconnect_aresetn] [get_bd_pins $transmitter/ARESETN]
      connect_bd_net [get_bd_pins design_peripheral_aresetn] [get_bd_pins $transmitter/S*_ARESETN]
    } else {
      connect_bd_net [get_bd_pins sfp_tx_clock] [get_bd_pins $transmitter/ACLK] [get_bd_pins $transmitter/S*_ACLK]
      connect_bd_net [get_bd_pins sfp_tx_resetn] [get_bd_pins $transmitter/ARESETN] [get_bd_pins $transmitter/S*_ARESETN]
    }

    for {variable i 0} {$i < $num_sender} {incr i} {
      connect_bd_intf_net [get_bd_intf_pins $transmitter/S[format "%02d" $i]_AXIS] [get_bd_intf_pins S[format "%02d" $i]_AXIS]
    }

    current_bd_instance $current
  }

  ######## END GENERATE FOR MODES ########

  # Connect the clocks of a PE for PE synchronization
  # @param interface the AXIS-Interface of the PE
  # @param port the port the interface is connected to
  # @param direction 'rx' for recieving, 'tx' for transmitting
  proc connect_clock_pe_sync {interface port direction} {
    set PE [get_bd_cells -of_objects [get_bd_intf_pins $interface]]
    # Check number of clocks
    set clks [get_bd_pins -of_objects $PE -filter {type == clk}]
    set found_clk false

    foreach clk $clks {
      # Currently only supports separate clock for each interface
      set interfaces [get_property CONFIG.ASSOCIATED_BUSIF $clk]
      if {$interface == "$PE/$interfaces"} {
        set found_clk true
        disconnect_bd_net [get_bd_nets -of_objects $clk] $clk
        connect_bd_net [get_bd_pins $port/sfp_${direction}_clock] $clk

        set rst [get_bd_pins $PE/[get_property CONFIG.ASSOCIATED_RESET $clk]]
        disconnect_bd_net [get_bd_nets -of_objects $rst]  $rst
        connect_bd_net [get_bd_pins $port/sfp_${direction}_resetn] $rst
      }
    }

    if {!$found_clk} {
      puts "Didn't find clock input for AXIS interface $interface."
      puts "When using PE synchronization a separate clock for each AXIS interface is required."
      exit
    }
  }
  
}



tapasco::register_plugin "platform::sfpplus::validate_sfp_ports" "pre-arch"
