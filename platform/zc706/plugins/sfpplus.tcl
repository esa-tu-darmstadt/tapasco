namespace eval sfpplus {
  namespace export generate_sfp_cores
  variable available_ports 4
  variable rx_ports       {}
  variable tx_ports       {}
  variable tx_dis_ports   {}
  variable sig_det_ports  {}
  variable tx_fault_ports {}

  proc find_ID {input} {
    variable composition
    for {variable o 0} {$o < [llength $composition] -1} {incr o} {
      if {[regexp ".*:$input:.*" [dict get $composition $o vlnv]]} {
        return $o
      }
    }
    return -1
  }

  proc makeInverter {name} {
    variable ret [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 $name]
    set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $name]
    return $ret
  }

# Start: Validating Configuration
  proc validate_sfp_ports {{args {}}} {
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {
      variable available_ports
      variable composition [tapasco::get_composition]
      set f [tapasco::get_feature "SFPPLUS"]
      variable ky [dict keys $f]
      variable used_ports [list]

      puts "Checking SFP-Network for palausability:"
      # Check if Board supports enough SFP-Ports
      if { [llength $ky] > $available_ports} {
        puts "To many SFP-Ports specified (Max: $available_ports)"
        exit
      }

      #Check if Port Config is valid
      for {variable i 0} {$i < [llength $ky]-1} {incr i} {
        variable port [dict get $f [lindex $ky $i]]
        lappend used_ports [dict get $port PORT]
        variable mode [dict get $port mode]
        puts "Port: [dict get $port PORT]"
        puts "  Mode: $mode"
        dict set [lindex [dict get $port kernel] 0] vlnv " "
        switch $mode {
          singular   { validate_singular $port }
          broadcast  { validate_broadcast $port }
          roundrobin { validate_roundrobin $port }
          default {
            puts "Mode $mode not supported"
            exit
          }
        }
        variable unique_ports [lsort -unique $used_ports]
        if { [llength $used_ports] > [llength $unique_ports]} {
          puts "Port-specification not Unique (Ports Specified: [lsort $used_ports])"
          exit
        }
      }
      puts "SFP-Config OK"

    }
    return {}
  }

  # validate Port for singular mode
  proc validate_singular {config} {
    variable kern [dict get $config kernel]
    variable composition
    if {[llength $kern] == 1} {
      puts "  Kernel:"
      variable x [lindex $kern 0]
      dict set $x "vlnv" " "
      dict with  x {
        puts "    ID: $ID"
        puts "    Count: $Count"
        puts "    Recieve:  $interface_rx"
        puts "    Transmit: $interface_tx"
        variable kernelID [find_ID $ID]
        if { $kernelID != -1 } {
          variable newCount [expr {[dict get $composition $kernelID count] - $Count}]
          set vlnv [dict get $composition $kernelID vlnv]
          if { $newCount <= 0} {
            puts "Not Enough Instances of Kernel $ID"
            exit
          }
          [dict set composition $kernelID count $newCount]
        } else {
          puts "Kernel not found"
          exit
        }
      }
    } else {
      puts "Only one Kernel allowed in Singular mode"
      exit
    }
  }

  # validate Port for broadcast mode
  proc validate_broadcast {config} {
    variable composition
    variable kern [dict get $config kernel]
    for {variable c 0} {$c < [llength $kern]} {incr c} {
      puts "  Kernel_$c:"
      variable x [lindex $kern $c]
      dict set $x "vlnv" " "
      dict with  x {
        puts "    ID: $ID"
        puts "    Count: $Count"
        puts "    Recieve:  $interface_rx"
        puts "    Transmit: $interface_tx"
        variable kernelID [find_ID $ID]
        if { $kernelID != -1 } {
          variable newCount [expr {[dict get $composition $kernelID count] - $Count}]
          set vlnv [dict get $composition $kernelID vlnv]
          if { $newCount <= 0} {
            puts "Not Enough Instances of Kernel $ID"
            exit
          }
          [dict set composition $kernelID count $newCount]
        } else {
          puts "Kernel not found"
          exit
        }
      }
    }
  }

  # validate Port for roundrobin mode
  proc validate_roundrobin {config} {
    variable composition
    variable kern [dict get $config kernel]
    for {variable c 0} {$c < [llength $kern]} {incr c} {
      puts "  Kernel_$c:"
      variable x [lindex $kern $c]
      dict set $x "vlnv" " "
      dict with  x {
        puts "    ID: $ID"
        puts "    Count: $Count"
        puts "    Recieve:  $interface_rx"
        puts "    Transmit: $interface_tx"
        variable kernelID [find_ID $ID]
        if { $kernelID != -1 } {
          variable newCount [expr {[dict get $composition $kernelID count] - $Count}]
          set vlnv [dict get $composition $kernelID vlnv]
          puts "VLNV: $vlnv"
          if { $newCount <= 0} {
            puts "Not Enough Instances of Kernel $ID"
          [dict set composition $kernelID count $newCount]
          exit
        }
        } else {
          puts "Kernel not found"
          exit
        }
      }
    }
  }
# END: Validating Configuration

# Generate Network Setup

proc generate_sfp_ports {{args {}}} {
  current_bd_instance /arch
  create_bd_pin -type clk -dir I sfp_clock
  create_bd_pin -type rst -dir I sfp_clock_reset
  foreach i {0 1 2 3} {
    create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_RX_$i
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_TX_$i
  }
  #generate_sfp_clock
  generate_cores {0 1 2 3} false
}

proc generate_cores {ports sync} {
  current_bd_instance /
  tapasco::subsystem::create Network
  current_bd_instance Network

  create_bd_pin -type clk -dir O sfp_clock
  create_bd_pin -type rst -dir O sfp_clock_reset

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_Network

  create_bd_port -dir I refclk_p
  create_bd_port -dir I refclk_n

  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 AXI_Config
  set_property -dict [list CONFIG.NUM_SI {1}] [get_bd_cells AXI_Config]
  set_property CONFIG.NUM_MI [llength $ports] [get_bd_cells AXI_Config]

  connect_bd_intf_net [get_bd_intf_pins AXI_Config/S00_AXI] [get_bd_intf_pins S_Network]
  connect_bd_net [get_bd_pins AXI_Config/S00_ACLK] [get_bd_pins design_clk]
  connect_bd_net [get_bd_pins AXI_Config/S00_ARESETN] [get_bd_pins design_interconnect_aresetn]
  connect_bd_net [get_bd_pins AXI_Config/ACLK] [get_bd_pins design_clk]
  connect_bd_net [get_bd_pins AXI_Config/ARESETN] [get_bd_pins design_interconnect_aresetn]
  connect_bd_net [get_bd_pins AXI_Config/M*_ACLK] [get_bd_pins design_clk]
  connect_bd_net [get_bd_pins AXI_Config/M*_ARESETN] [get_bd_pins design_interconnect_aresetn]

  for {set i 0} {$i < [llength $ports]} {incr i} {
    variable port [lindex $ports $i]
# Global Ports
    create_bd_port -dir O txp_$port
    create_bd_port -dir O txn_$port
    create_bd_port -dir O tx_disable_$port


    create_bd_port -dir I rxp_$port
    create_bd_port -dir I rxn_$port
    create_bd_port -dir I signal_detect_$port
    create_bd_port -dir I tx_fault_$port

# Local Pins
    create_bd_pin -dir O txp_$port
    create_bd_pin -dir O txn_$port
    create_bd_pin -dir O tx_disable_$port

    create_bd_pin -dir I rxp_$port
    create_bd_pin -dir I rxn_$port
    create_bd_pin -dir I signal_detect_$port
    create_bd_pin -dir I tx_fault_$port

    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_RX_$port
    create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_TX_$port
# Connect Local pins to Global Ports
    connect_bd_net [get_bd_ports /txp_$port] [get_bd_pins txp_$port]
    connect_bd_net [get_bd_ports /txn_$port] [get_bd_pins txn_$port]
    connect_bd_net [get_bd_ports /tx_disable_$port] [get_bd_pins tx_disable_$port]

    connect_bd_net [get_bd_ports /rxp_$port] [get_bd_pins rxp_$port]
    connect_bd_net [get_bd_ports /rxn_$port] [get_bd_pins rxn_$port]
    connect_bd_net [get_bd_ports /signal_detect_$port] [get_bd_pins signal_detect_$port]
    connect_bd_net [get_bd_ports /tx_fault_$port] [get_bd_pins tx_fault_$port]

# Direct Pins
    variable group [create_bd_cell -type hier "PORT_$port"]
    current_bd_instance $group

    create_bd_pin -dir O txp
    create_bd_pin -dir O txn
    create_bd_pin -dir O tx_disable

    create_bd_pin -dir I rxp
    create_bd_pin -dir I rxn
    create_bd_pin -dir I signal_detect
    create_bd_pin -dir I tx_fault
    create_bd_pin -dir I design_clk
    create_bd_pin -dir I design_interconnect_aresetn
    create_bd_pin -dir I design_peripheral_aresetn

    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_RX
    create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 AXIS_TX
    create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_Config

    connect_bd_intf_net [get_bd_intf_pins S_AXI_Config] [get_bd_intf_pins /Network/AXI_Config/M[format %02d $port]_AXI]
    connect_bd_net [get_bd_pins txp] [get_bd_pins /Network/txp_$port]
    connect_bd_net [get_bd_pins txn] [get_bd_pins /Network/txn_$port]
    connect_bd_net [get_bd_pins tx_disable] [get_bd_pins /Network/tx_disable_$port]

    connect_bd_net [get_bd_pins rxp] [get_bd_pins /Network/rxp_$port]
    connect_bd_net [get_bd_pins rxn] [get_bd_pins /Network/rxn_$port]
    connect_bd_net [get_bd_pins signal_detect] [get_bd_pins /Network/signal_detect_$port]
    connect_bd_net [get_bd_pins tx_fault] [get_bd_pins /Network/tx_fault_$port]
    connect_bd_net [get_bd_pins design_clk] [get_bd_pins /Network/design_clk]
    connect_bd_net [get_bd_pins design_interconnect_aresetn] [get_bd_pins /Network/design_interconnect_aresetn]

    connect_bd_intf_net [get_bd_intf_pins AXIS_RX] [get_bd_intf_pins /Network/AXIS_RX_$port]
    connect_bd_intf_net [get_bd_intf_pins AXIS_TX] [get_bd_intf_pins /Network/AXIS_TX_$port]

    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_10g_ethernet:3.1 Ethernet10G
    if {$i > 0} {
      set_property -dict [list CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {0} CONFIG.autonegotiation {0} CONFIG.fec {0} CONFIG.Statistics_Gathering {0} CONFIG.Statistics_Gathering {false} CONFIG.TransceiverControl {true} CONFIG.DRP {false}] [get_bd_cells Ethernet10G]
      connect_bd_net [get_bd_pins $main_core/qplllock_out]           [get_bd_pins Ethernet10G/qplllock]
      connect_bd_net [get_bd_pins $main_core/qplloutclk_out]         [get_bd_pins Ethernet10G/qplloutclk]
      connect_bd_net [get_bd_pins $main_core/qplloutrefclk_out]      [get_bd_pins Ethernet10G/qplloutrefclk]
      connect_bd_net [get_bd_pins $main_core/reset_counter_done_out] [get_bd_pins Ethernet10G/reset_counter_done]
      connect_bd_net [get_bd_pins $main_core/txusrclk_out]           [get_bd_pins Ethernet10G/txusrclk]
      connect_bd_net [get_bd_pins $main_core/txusrclk2_out]          [get_bd_pins Ethernet10G/txusrclk2]
      connect_bd_net [get_bd_pins $main_core/txuserrdy_out]          [get_bd_pins Ethernet10G/txuserrdy]
      connect_bd_net [get_bd_pins $main_core/coreclk_out]            [get_bd_pins Ethernet10G/coreclk]
      connect_bd_net [get_bd_pins $main_core/gttxreset_out]          [get_bd_pins Ethernet10G/gttxreset]
      connect_bd_net [get_bd_pins $main_core/gtrxreset_out]          [get_bd_pins Ethernet10G/gtrxreset]
      connect_bd_net [get_bd_pins $main_core/gttxreset_out]          [get_bd_pins Ethernet10G/areset_coreclk]
      connect_bd_net [get_bd_pins /Network/design_peripheral_areset] [get_bd_pins Ethernet10G/areset]
    } else {
      set_property -dict [list CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {1} CONFIG.autonegotiation {0} CONFIG.fec {0} CONFIG.Statistics_Gathering {0} CONFIG.Statistics_Gathering {false} CONFIG.TransceiverControl {true} CONFIG.DRP {false}] [get_bd_cells Ethernet10G]
      set main_core [get_bd_cells Ethernet10G]
      connect_bd_net [get_bd_ports /refclk_p] [get_bd_pins Ethernet10G/refclk_p]
      connect_bd_net [get_bd_ports /refclk_n] [get_bd_pins Ethernet10G/refclk_n]
      connect_bd_net [get_bd_pins Ethernet10G/reset] [get_bd_pins /Network/design_peripheral_areset]
      connect_bd_net [get_bd_pins Ethernet10G/coreclk_out] [get_bd_pins /Network/sfp_clock]

      set out_inv [makeInverter "out_inverter"]
      connect_bd_net [get_bd_pins Ethernet10G/areset_datapathclk_out] [get_bd_pins $out_inv/Op1]
      connect_bd_net [get_bd_pins /Network/sfp_clock_reset] [get_bd_pins $out_inv/Res]
    }

    if {$sync} {
# clocks already synced nothing to do here
      connect_bd_intf_net [get_bd_intf_pins Ethernet10G/m_axis_rx] [get_bd_intf_pins AXIS_RX]
      connect_bd_intf_net [get_bd_intf_pins Ethernet10G/s_axis_tx] [get_bd_intf_pins AXIS_TX]
    } else {
# syncing SFP CLOCK to Design_CLK
      create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 ethernet_rx
      set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1} CONFIG.M00_FIFO_DEPTH {2048} CONFIG.M00_FIFO_MODE {1}] [get_bd_cells ethernet_rx]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 ethernet_tx
      set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1} CONFIG.M00_FIFO_DEPTH {2048} CONFIG.M00_FIFO_MODE {1}] [get_bd_cells ethernet_tx]

      connect_bd_intf_net [get_bd_intf_pins Ethernet10G/m_axis_rx] [get_bd_intf_pins ethernet_rx/S00_AXIS]
      connect_bd_intf_net [get_bd_intf_pins Ethernet10G/s_axis_tx] [get_bd_intf_pins ethernet_tx/M00_AXIS]

      connect_bd_intf_net [get_bd_intf_pins AXIS_RX] [get_bd_intf_pins ethernet_rx/M00_AXIS]
      connect_bd_intf_net [get_bd_intf_pins AXIS_TX] [get_bd_intf_pins ethernet_tx/S00_AXIS]

      connect_bd_net [get_bd_pins ethernet_rx/M00_AXIS_ACLK] [get_bd_pins design_clk]
      connect_bd_net [get_bd_pins ethernet_rx/M00_AXIS_ARESETN] [get_bd_pins design_interconnect_aresetn]
      connect_bd_net [get_bd_pins ethernet_tx/S00_AXIS_ACLK] [get_bd_pins design_clk]
      connect_bd_net [get_bd_pins ethernet_tx/S00_AXIS_ARESETN] [get_bd_pins design_interconnect_aresetn]

      connect_bd_net [get_bd_pins ethernet_tx/M00_AXIS_ACLK] [get_bd_pins $main_core/coreclk_out]
      connect_bd_net [get_bd_pins ethernet_tx/M00_AXIS_ARESETN] [get_bd_pins $out_inv/Res]
      connect_bd_net [get_bd_pins ethernet_rx/S00_AXIS_ACLK] [get_bd_pins $main_core/coreclk_out]
      connect_bd_net [get_bd_pins ethernet_rx/S00_AXIS_ARESETN] [get_bd_pins $out_inv/Res]

      connect_bd_net [get_bd_pins ethernet_rx/ACLK] [get_bd_pins $main_core/coreclk_out]
      connect_bd_net [get_bd_pins ethernet_rx/ARESETN] [get_bd_pins $out_inv/Res]
      connect_bd_net [get_bd_pins ethernet_tx/ACLK] [get_bd_pins design_clk]
      connect_bd_net [get_bd_pins ethernet_tx/ARESETN] [get_bd_pins design_interconnect_aresetn]
    }

    connect_bd_intf_net [get_bd_intf_pins Ethernet10G/s_axi] [get_bd_intf_pins S_AXI_Config]
    connect_bd_net [get_bd_pins Ethernet10G/txp] [get_bd_pins txp]
    connect_bd_net [get_bd_pins Ethernet10G/txn] [get_bd_pins txn]
    connect_bd_net [get_bd_pins Ethernet10G/rxp] [get_bd_pins rxp]
    connect_bd_net [get_bd_pins Ethernet10G/rxn] [get_bd_pins rxn]
    connect_bd_net [get_bd_pins Ethernet10G/dclk] [get_bd_pins design_clk]
    connect_bd_net [get_bd_pins Ethernet10G/s_axi_aclk] [get_bd_pins design_clk]
    connect_bd_net [get_bd_pins Ethernet10G/s_axi_aresetn] [get_bd_pins design_peripheral_aresetn]
    connect_bd_net [get_bd_pins Ethernet10G/tx_fault] [get_bd_pins tx_fault]
    connect_bd_net [get_bd_pins Ethernet10G/tx_disable] [get_bd_pins tx_disable]
    connect_bd_net [get_bd_pins Ethernet10G/signal_detect] [get_bd_pins signal_detect]
    current_bd_instance /Network
  }
  current_bd_instance /
}

proc gernerate_broadcast {input port sync} {
    current_bd_instance arch
    variable slaves [llength input]
    create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1  broadcast_rx_$port
    set_property -dict [ list CONFIG.NUM_MI {$slaves}] [get_bd_cells broadcast_rx_$port]
    create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 broadcast_tx_$port
    set_property -dict [list CONFIG.NUM_SI {$slaves} CONFIG.NUM_MI {1} CONFIG.ARB_ON_TLAST {1} CONFIG.ARB_ALGORITHM {3} CONFIG.M00_FIFO_DEPTH {2048}] [get_bd_cells broadcast_tx_$port]

    connect_bd_intf_net [get_bd_intf_pins broadcast_rx_$port/S_AXIS] -boundary_type upper [get_bd_intf_pins Network/Port_$port/AXIS_RX]
    connect_bd_intf_net [get_bd_intf_pins broadcast_tx_$port/M00_AXIS] -boundary_type upper [get_bd_intf_pins Network/Port_$port/AXIS_TX]

    for {set i 0} {$i < $slaves} {incr i} {
      variable ip [lindex input $i]
      dict with $ip {
        connect_bd_intf_net [get_bd_intf_pins $core/$rx] [get_bd_intf_pins broadcast_rx_$port/M${[format %02d $i]}_AXIS]
        connect_bd_intf_net [get_bd_intf_pins $core/$tx] [get_bd_intf_pins broadcast_tx_$port/S${[format %02d $i]}_AXIS]
      }
    }
}

proc gernerate_roundrobin {input} {
      #create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1  axis_distributer_rx_[dict get $input "PORT"]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 axis_interconnect_tx_[dict get $input "PORT"]
}

#SI5324-Clock Setup
  proc generate_sfp_clock { } {
    puts "Setting up the Clock for 10G-SFP Config"

    create_bd_port -dir I gt_refclk_clk_p
    create_bd_port -dir I gt_refclk_clk_n
    set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_clk_p]
    set_property CONFIG.FREQ_HZ 156250000 [get_bd_ports /gt_refclk_clk_n]

    puts $constraints_file {set_property PACKAGE_PIN AC8 [get_ports gt_refclk_clk_p]}
    puts $constraints_file {create_clock -period 6.400 -name gt_ref_clk [get_ports gt_refclk_clk_p]}

    puts $constraints_file {# Main I2C Bus - 100KHz - SUME}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports iic_scl_io]}
    puts $constraints_file {set_property SLEW SLOW [get_ports iic_scl_io]}
    puts $constraints_file {set_property DRIVE 16 [get_ports iic_scl_io]}
    puts $constraints_file {set_property PULLUP true [get_ports iic_scl_io]}
    puts $constraints_file {set_property PACKAGE_PIN AK24 [get_ports iic_scl_io]}

    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports iic_sda_io]}
    puts $constraints_file {set_property SLEW SLOW [get_ports iic_sda_io]}
    puts $constraints_file {set_property DRIVE 16 [get_ports iic_sda_io]}
    puts $constraints_file {set_property PULLUP true [get_ports iic_sda_io]}
    puts $constraints_file {set_property PACKAGE_PIN AK25 [get_ports iic_sda_io]}

    puts $constraints_file {# i2c_reset[0] - i2c_mux reset - high active}
    puts $constraints_file {# i2c_reset[1] - si5324 reset - high active}
    puts $constraints_file {set_property SLEW SLOW [get_ports {i2c_reset[*]}]}
    puts $constraints_file {set_property DRIVE 16 [get_ports {i2c_reset[*]}]}
    puts $constraints_file {set_property PACKAGE_PIN AM39 [get_ports {i2c_reset[0]}]} #Pin F20?
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports {i2c_reset[0]}]}
    puts $constraints_file {set_property PACKAGE_PIN BA29 [get_ports {i2c_reset[1]}]}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports {i2c_reset[1]}]}

    create_bd_port -dir O -from 1 -to 0 i2c_reset

    set num_clocks_old [get_property CONFIG.NUM_OUT_CLKS [get_bd_cells $instance/Memory/design_clk_generator]]
    set num_clocks [expr "$num_clocks_old + 1"]
    set_property -dict [list CONFIG.CLKOUT${num_clocks}_USED {true} CONFIG.CLKOUT${num_clocks}_REQUESTED_OUT_FREQ 100] [get_bd_cells $instance/Memory/design_clk_generator]
    set slow_clk [get_bd_pins $instance/Memory/design_clk_generator/clk_out${num_clocks}]

    set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells $instance/axi_ic_from_host]]
    set num_mi [expr "$num_mi_old + 1"]
    set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells $instance/axi_ic_from_host]

    connect_bd_net [get_bd_pins $instance/Resets/pcie_aclk] [get_bd_pins $instance/axi_ic_from_host/[format "M%02d_ACLK" $num_mi_old]]
    connect_bd_net [get_bd_pins $instance/Resets/pcie_peripheral_aresetn] [get_bd_pins $instance/axi_ic_from_host/[format "M%02d_ARESETN" $num_mi_old]]

    set reset_inverter [tapasco::createLogicInverter "reset_inverter"]
    connect_bd_net [get_bd_pins $instance/pcie_perst] [get_bd_pins $reset_inverter/Op1]

    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.0 SI5324Prog_0
    set_property -dict [list CONFIG.C_SCL_INERTIAL_DELAY {5} CONFIG.C_SDA_INERTIAL_DELAY {5} CONFIG.C_GPO_WIDTH {2}] [get_bd_cells SI5324Prog_0]
    create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 IIC
    connect_bd_intf_net [get_bd_intf_ports /IIC] [get_bd_intf_pins SI5324Prog_0/IIC]

    connect_bd_intf_net [get_bd_intf_pins $instance/axi_ic_from_host/[format "M%02d_AXI" $num_mi_old]] [get_bd_intf_pins SI5324Prog_0/S_AXI]

    connect_bd_net [get_bd_pins SI5324Prog_0/s_axi_aclk] [get_bd_pins $instance/Resets/pcie_aclk]
    connect_bd_net [get_bd_pins SI5324Prog_0/s_axi_aresetn] [get_bd_pins $instance/Resets/pcie_peripheral_aresetn]

    connect_bd_net [get_bd_ports /i2c_reset] [get_bd_pins SI5324Prog_0/gpo]
  }

  proc addressmap {{args {}}} {
    if {[tapasco::is_feature_enabled "SFPPLUS"]} {

      set networkIPs [get_bd_cells -of [get_bd_intf_pins -filter {NAME =~ "*sfp_axis_rx*"} uArch/target_ip_*/*]]

      set host_addr_space [get_bd_addr_space "/PCIe/axi_pcie3_0/M_AXI"]
      set offset 0x0000000000400000

      set addr_space [get_bd_addr_segs "Network/SI5324Prog_0/S_AXI/Reg"]
      create_bd_addr_seg -range 64K -offset $offset $host_addr_space $addr_space "Network_i2c"
    }
    return {}
  }

}

tapasco::register_plugin "platform::sfpplus::validate_sfp_ports" "pre-arch"
tapasco::register_plugin "platform::sfpplus::generate_sfp_ports" "pre-platform"
#tapasco::register_plugin "platform::sfpplus::addressmap" "post-address-map"
