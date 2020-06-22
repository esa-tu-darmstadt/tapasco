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


namespace eval ::tapasco::ip {
  set stdcomps [dict create]

  # check if we're running inside Vivado
  if {[llength [info commands version]] > 0} {
    # source IP catalog VLNVs for the current Vivado version
    set cip [format "$::env(TAPASCO_HOME_TCL)/common/common_%s.tcl" [version -short]]
    if {! [file exists $cip]} {
      set cip_org $cip
      set cip [format "$::env(TAPASCO_HOME_TCL)/common/common_%s.tcl" "[::tapasco::get_vivado_version_major].[::tapasco::get_vivado_version_minor]"]
      if {! [file exists $cip]} {
        puts "Could not find $cip_org, Vivado [version -short] is not supported yet!"
        exit 1
      }
    }

    source $cip
  } {
    puts "Skipping IP catalog."
  }

  # Automatically generate create proc for every known IP block.
  # Can be overridden below.
  foreach comp [dict keys $stdcomps] {
    namespace export create_${comp}
    set vlnv [dict get $stdcomps $comp "vlnv"]
    proc create_${comp} {name} {
      variable stdcomps
      set comp_name [regsub {^([^:]*::)*create_} [lindex [info level 0] 0] {}]
      set vlnv [dict get $stdcomps $comp_name "vlnv"]
      puts "Creating component $name ..."
      puts "  VLNV: $vlnv"
      return [create_bd_cell -type ip -vlnv $vlnv $name]
    }
  }

  namespace export get_vlnv

  # Returns the VLNV for a given abstract TaPaSCo name.
  proc get_vlnv {name} {
    variable stdcomps
    if {! [dict exists $stdcomps $name]} { error "VLNV for $name was not found in IP catalog!" }
    return [dict get $stdcomps $name vlnv]
  }

  # Instantiates binary counter IP core.
  # @param name Name of the instance.
  # @param output_width Bit width of the counter.
  # @return bd_cell of the instance.
  proc create_bincnt {name width} {
    variable stdcomps
    puts "Creating $width-bits binary counter ..."
    puts "  VLNV: [dict get $stdcomps bincnt vlnv]"

    set bincnt [create_bd_cell -type ip -vlnv [dict get $stdcomps bincnt vlnv] $name]
    # set bit-width
    set_property -dict [list CONFIG.Output_Width $width CONFIG.Restrict_Count {false}] $bincnt
    return $bincnt
  }

  # Instantiates an AXI4 Interrupt Controller IP core.
  # @param name Name of the instance (default: axi_intc).
  # @return bd_cell of the instance.
  proc create_axi_irqc {{name axi_intc}} {
    variable stdcomps
    puts "Creating interrupt control $name ..."
    puts "  VLNV: [dict get $stdcomps axi_irqc vlnv]"

    set irqc [create_bd_cell -type ip -vlnv [dict get $stdcomps axi_irqc vlnv] $name]
    # activate edge-sensitive interrupts
    set_property -dict [list \
      CONFIG.C_KIND_OF_INTR.VALUE_SRC USER \
      CONFIG.C_KIND_OF_INTR {0xFFFFFFFF} \
      CONFIG.C_IRQ_CONNECTION {1} \
    ] $irqc
    # set_property -dict [list CONFIG.C_EN_CASCADE_MODE {1} CONFIG.C_CASCADE_MASTER {1}] $irqc
    return $irqc
  }

  # Instantiates an AXI4 Interconnect IP.
  # @param name Name of the instance.
  # @param no_slaves Number of AXI4 Slave interfaces.
  # @param no_masters Number of AXI4 Master interfaces.
  # @return bd_cell of the instance.
  proc create_axi_ic {name no_slaves no_masters} {
    variable stdcomps
    puts "Creating AXI Interconnect $name with $no_slaves slaves and $no_masters masters..."
    puts "  VLNV: [dict get $stdcomps axi_ic vlnv]"

    set ic [create_bd_cell -type ip -vlnv [dict get $stdcomps axi_ic vlnv] $name]
    set props [list CONFIG.NUM_SI $no_slaves CONFIG.NUM_MI $no_masters]
    for {set i 0} {$i < $no_slaves} {incr i} {
      set ifname [format "CONFIG.S%02d_HAS_REGSLICE" $i]
      lappend props $ifname {4}
    }
    for {set i 0} {$i < $no_masters} {incr i} {
      set ifname [format "CONFIG.M%02d_HAS_REGSLICE" $i]
      lappend props $ifname {4}
    }
    set_property -dict $props $ic
    return $ic
  }

  # Instantiates an AXI4-Stream Interconnect IP.
  # @param name Name of the instance.
  # @param no_slaves Number of AXI4-Stream Slave interfaces.
  # @param no_masters Number of AXI4-Stream Master interfaces.
  # @return bd_cell of the instance.
  proc create_axis_ic {name no_slaves no_masters} {
    variable stdcomps
    puts "Creating AXI-Stream Interconnect $name with $no_slaves slaves and $no_masters masters..."
    puts "  VLNV: [dict get $stdcomps axis_ic vlnv]"

    set ic [create_bd_cell -type ip -vlnv [dict get $stdcomps axis_ic vlnv] $name]
    set props [list CONFIG.NUM_SI $no_slaves CONFIG.NUM_MI $no_masters]
    set_property -dict $props $ic
    return $ic
  }

  # Instantiates an AXI4 Smartconnect IP.
  # @param name Name of the instance.
  # @param no_slaves Number of AXI4 Slave interfaces.
  # @param no_masters Number of AXI4 Master interfaces.
  # @param no_clocks Number of different clocks used.
  # @return bd_cell of the instance.
  proc create_axi_sc {name no_slaves no_masters {num_clocks 1}} {
    variable stdcomps
    puts "Creating AXI Smartconnect $name with $no_slaves slaves, $no_masters masters and $num_clocks clocks..."
    puts "  VLNV: [dict get $stdcomps axi_sc vlnv]"

    set ic [create_bd_cell -type ip -vlnv [dict get $stdcomps axi_sc vlnv] $name]
    set props [list CONFIG.NUM_SI $no_slaves CONFIG.NUM_MI $no_masters CONFIG.NUM_CLKS $num_clocks CONFIG.HAS_ARESETN {0}]
    set_property -dict $props $ic
    return $ic
  }

  proc connect_sc_default_clocks {name {main_clk "design"}} {
    puts "Connecting AXI Smartconnect $name to the default clocks..."
    set_property -dict [list CONFIG.NUM_CLKS {3}] $name

    set clk [tapasco::subsystem::get_port $main_clk "clk"]
    puts "Connecting clock of type $main_clk as main clock -> $clk"
    connect_bd_net [get_bd_pins $clk] [get_bd_pins $name/aclk]

    set i 1
    foreach c {host design mem} {
      if {$c != $main_clk} {
        set clk [tapasco::subsystem::get_port $c "clk"]
        puts "Connecting clock of type $c -> $clk"
        connect_bd_net [get_bd_pins $clk] [get_bd_pins $name/[format "aclk%d" $i]]
        incr i
      }
    }
  }

  # Instantiates a Zynq-7000 Processing System IP core.
  # @param name Name of the instance (default: ps7).
  # @param preset Name of board preset to apply (default: ::tapasco::get_board_preset).
  # @param freq_mhz FCLK_0 frequency in MHz (default: ::tapasco::get_design_frequency).
  # @return bd_cell of the instance.
  proc create_ps {{name ps7} {preset [::tapasco::get_board_preset]} {freq_mhz [::tapasco::get_design_frequency]}} {
    variable stdcomps
    puts "Creating Zynq-7000 series IP core ..."
    puts "  VLNV: [dict get $stdcomps ps vlnv]"
    puts "  Preset: $preset"

    set ps [create_bd_cell -type ip -vlnv [dict get $stdcomps ps vlnv] $name]
    if {$preset != {} && $preset != ""} {
      set_property -dict [list CONFIG.preset $preset] $ps
      apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" } $ps
    } {
      apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" } $ps
    }
    return $ps
  }

  # Instantiates a Zynq-Ultra Scale + Processing System IP core.
  # @param name Name of the instance (default: ps7).
  # @param preset Name of board preset to apply (default: ::tapasco::get_board_preset).
  # @param freq_mhz FCLK_0 frequency in MHz (default: ::tapasco::get_design_frequency).
  # @return bd_cell of the instance.
  proc create_ultra_ps {{name ultra_ps} {preset [::tapasco::get_board_preset]} {freq_mhz [::tapasco::get_design_frequency]}} {
    variable stdcomps
    puts "Creating Zynq-US+ series IP core ..."
    puts "  VLNV: [dict get $stdcomps ultra_ps vlnv]"
    puts "  Preset: $preset"

    set ps [create_bd_cell -type ip -vlnv [dict get $stdcomps ultra_ps vlnv] $name]
    if {$preset != {} && $preset != ""} {
      apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" } $ps
    } {
      apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" } $ps
    }
    return $ps
  }

  # Instantiates a Zynq-7000 Processing System IP BFM simulation core.
  # @param name Name of the instance (default: ps7).
  # @param preset Name of board preset to apply (default: ::tapasco::get_board_preset).
  # @param freq_mhz FCLK_0 frequency in MHz (default: ::tapasco::get_design_frequency).
  # @return bd_cell of the instance.
  proc create_ps_bfm {{name ps7} {preset [::tapasco::get_board_preset]} {freq_mhz [::tapasco::get_design_frequency]}} {
    variable stdcomps
    puts "Creating Zynq-7000 series BFM IP core ..."
    puts "  VLNV: [dict get $stdcomps ps_bfm vlnv]"
    puts "  Preset: $preset"
    puts "  FCLK0 : $freq_mhz"

    set paramlist [list \
        CONFIG.PCW_USE_M_AXI_GP0 {1} \
        CONFIG.PCW_USE_M_AXI_GP1 {1} \
        CONFIG.PCW_USE_S_AXI_HP0 {1} \
        CONFIG.PCW_USE_S_AXI_HP1 {1} \
        CONFIG.PCW_USE_S_AXI_HP2 {1} \
        CONFIG.PCW_USE_S_AXI_HP3 {1} \
        CONFIG.PCW_FCLK_CLK0_FREQ [expr $freq_mhz * 1000000] \
      ]

    set ps [create_bd_cell -type ip -vlnv [dict get $stdcomps ps_bfm vlnv] $name]
    set_property -dict $paramlist $ps
    return $ps
  }

  # Instantiates a XLConcat bit concatenation IP core.
  # @param name Name of the instance.
  # @param inputs Number of input wires.
  # @return bd_cell of the instance.
  proc create_xlconcat {name inputs} {
    variable stdcomps
    puts "Creating xlconcat $name with $inputs ..."
    puts "  VLNV: [dict get $stdcomps xlconcat vlnv]"

    set xlconcat [create_bd_cell -type ip -vlnv [dict get $stdcomps xlconcat vlnv] $name]
    set_property -dict [list CONFIG.NUM_PORTS $inputs] $xlconcat
    return $xlconcat
  }

  # Instantiates a XLSlice bit slicing IP core.
  # @param name Name of the instance.
  # @param width Number of input wires.
  # @param bit Selected bit.
  # @return bd_cell of the instance.
  proc create_xlslice {name width bit} {
    variable stdcomps
    puts "Creating xlslice $name with $width-bit width and bit $bit selected ..."
    puts "  VLNV: [dict get $stdcomps xlslice vlnv]"

    set xlslice [create_bd_cell -type ip -vlnv [dict get $stdcomps xlslice vlnv] $name]
    set_property -dict [list CONFIG.DIN_WIDTH $width CONFIG.DIN_TO $bit CONFIG.DIN_FROM $bit CONFIG.DOUT_WIDTH 1] $xlslice
    return $xlslice
  }

  # Create a constant tie-off.
  # @param name Name of the instance.
  # @param width Number of input wires.
  # @param value Value of the constant.
  # @return bd_cell of the instance.
  proc create_constant {name width value} {
    variable stdcomps
    puts "Creating xlconstant $name with $width-bit width and value $value ..."
    puts "  VLNV: [dict get $stdcomps xlconst vlnv]"

    set xlconst [create_bd_cell -type ip -vlnv [dict get $stdcomps xlconst vlnv] $name]
    set_property -dict [list CONFIG.CONST_WIDTH $width CONFIG.CONST_VAL $value] $xlconst
    return $xlconst
  }

  # Instantiates a performance counter controller for the zedboard OLED display.
  # @param name Name of the instance.
  proc create_oled_ctrl {name} {
    variable stdcomps
    set composition [tapasco::get_composition]
    set pecount 0
    dict for {k v} $composition {
      set c [dict get $composition $k count]
      set pecount [expr "$pecount + $c"]
    }
    set oled_freq "10"
    set width [expr 128 / max(1, ($pecount / 32))]
    set cw [expr "log($width) / log(2)"]
    set p [expr round($oled_freq) * 1000]

    puts "Creating OLED Controller ..."
    puts "  VLNV       : [dict get $stdcomps oled_ctrl vlnv]"
    puts "  C_DELAY_1MS: $p"
    puts "  C_COLS     : $width"
    puts "  C_COUNTER_N: $pecount"
    puts "  C_COUNTER_W: $cw"

    set oc [create_bd_cell -type ip -vlnv [dict get $stdcomps oled_ctrl vlnv] $name]
    set xdc "$::env(TAPASCO_HOME_TCL)/common/ip/oled_pc/constraints/oled.xdc"
    read_xdc $xdc
    set_property PROCESSING_ORDER LATE [get_files $xdc]

    set_property -dict [list \
      "CONFIG.C_DELAY_1MS" "$p" \
      "CONFIG.C_COUNTER_N" "$pecount" \
      "CONFIG.C_COUNTER_W" [expr "round(log($width) / log(2))"] \
      "CONFIG.C_COLS" "$width" \
    ] $oc
    puts "  OLED controller frequency: $oled_freq MHz => C_DELAY_1MS = [expr round($oled_freq * 1000)]"
    return $oc
  }

  # Instantiates an AXI-MM full to lite stripper (assumes no bursts etc.).
  # @param name Name of the instance.
  proc create_mm_to_lite {name} {
    variable stdcomps
    puts "Creating AXI full to lite stripper ..."
    puts "  VLNV: [dict get $stdcomps mm_to_lite vlnv]"

    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps mm_to_lite vlnv] $name]
    set_property -dict [list CONFIG.C_S_AXI_ID_WIDTH {32}] $inst
    return $inst
  }

  proc create_msixusptrans {name pcie} {
    variable stdcomps
    puts "Creating translator for US+ MSIx VLNV and connecting it to $pcie ..."
    puts "  VLNV: [dict get $stdcomps msixusptrans vlnv]"

    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps msixusptrans vlnv] $name]
    connect_bd_net [get_bd_pins $pcie/cfg_interrupt_msix_address] [get_bd_pins $inst/m_cfg_interrupt_msix_address]
    connect_bd_net [get_bd_pins $pcie/cfg_interrupt_msix_data] [get_bd_pins $inst/m_cfg_interrupt_msix_data]
    connect_bd_net [get_bd_pins $inst/m_cfg_interrupt_msix_int] [get_bd_pins $pcie/cfg_interrupt_msix_int]
    connect_bd_net [get_bd_pins $pcie/cfg_interrupt_msix_enable] [get_bd_pins $inst/m_cfg_interrupt_msix_enable]
    connect_bd_net [get_bd_pins $pcie/cfg_interrupt_msi_fail] [get_bd_pins $inst/m_cfg_interrupt_msix_fail]
    connect_bd_net [get_bd_pins $inst/m_cfg_interrupt_msix_sent] [get_bd_pins $pcie/cfg_interrupt_msi_sent]
    return $inst
  }

  # Instantiates an AXI System Cache.
  # @param name Name of the instance.
  proc create_axi_cache {name {num_ports 3} {size 262144} {num_sets 2}} {
    variable stdcomps
    puts "Creating AXI System Cache ..."
    puts "  VLNV: [dict get $stdcomps system_cache vlnv]"
    puts "  ports: $num_ports"
    puts "  size: $size B"
    puts "  number sets: $num_sets"

    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps system_cache vlnv] $name]
    set_property -dict [list \
      CONFIG.C_CACHE_SIZE $size \
      CONFIG.C_M0_AXI_THREAD_ID_WIDTH {6} \
      CONFIG.C_NUM_GENERIC_PORTS $num_ports \
      CONFIG.C_NUM_OPTIMIZED_PORTS {0} \
      CONFIG.C_NUM_WAYS $num_sets \
    ] $inst
    return $inst
  }

  # Instantiates an AXI protocol converter.
  # @param name Name of the instance.
  # @param from Protocol on slave side (default: AXI4LITE)
  # @param to   Protocol on master side (default: AXI4)
  proc create_proto_conv {name {from "AXI4LITE"} {to "AXI4"}} {
    variable stdcomps
    puts "Creating AXI Protocol converter $name $from -> $to ..."
    set vlnv [dict get $stdcomps proto_conv vlnv]
    puts "  VLNV: $vlnv"

    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    set_property -dict [list CONFIG.MI_PROTOCOL $to CONFIG.SI_PROTOCOL $from] $inst
    return $inst
  }

  # Instantiates an AXI datawidth converter.
  # @param name Name of the instance.
  # @param from Data width on slave side (default: 256)
  # @param to   Data width on master side (default: 64)
  proc create_dwidth_conv {name {from "256"} {to ""}} {
    variable stdcomps
    puts "Creating AXI Datawidth converter $name $from -> $to ..."
    set vlnv [dict get $stdcomps dwidth_conv vlnv]
    puts "  VLNV: $vlnv"

    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    if {$to != ""} {
      set_property -dict [list CCONFIG.SI_DATA_WIDTH $from CONFIG.MI_DATA_WIDTH $to] $inst
    }
    return $inst
  }

  # Instantiates a System ILA core for AXI debugging.
  # @param name Name of the instance
  # @param ports Number of ports (optional, default: 1)
  # @param depth Data depth (optional, default: 1024)
  # @param stages Input pipeline stages (optional, default: 0)
  # @return block design cell (or error)
  proc create_system_ila {name {ports 1} {depth 1024} {stages 0}} {
    variable stdcomps
    puts "Creating System ILA $name ..."
    set vlnv [dict get $stdcomps system_ila vlnv]
    puts "  VLNV: $vlnv"
    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    set_property -dict [list \
      CONFIG.C_NUM_MONITOR_SLOTS $ports \
      CONFIG.C_DATA_DEPTH $depth \
      CONFIG.C_INPUT_PIPE_STAGES $stages \
    ] $inst
    return $inst
  }

  # Instantiates a AXI BRAM controller used as the TaPaSCo status core.
  # @param name Name of the instance.
  # @param ids  List of kernel IDs.
  proc create_tapasco_status {name {ids {}}} {
    puts "Creating custom status core ..."
    puts "  IDs : $ids"

    # create the IP core
    set base [tapasco::ip::create_bram_ctrl "${name}_base"]
    set axi [tapasco::ip::create_axi_bram_ctrl $name]

    set_property -dict [list CONFIG.DATA_WIDTH {64} \
                             CONFIG.PROTOCOL {AXI4} \
                             CONFIG.SINGLE_PORT_BRAM {1} \
                             CONFIG.ECC_TYPE {0}] $axi

    connect_bd_intf_net [get_bd_intf_pins $base/BRAM_PORTA] [get_bd_intf_pins $axi/BRAM_PORTA]

    return $axi
  }

  # Generate Infrastructure as JSON file and generate COE file as BRAM source
  proc update_tapasco_status_base {name} {
    puts "  sourcing JSON lib ..."
    source -notrace "$::env(TAPASCO_HOME_TCL)/common/json_write.tcl"
    package require json::write

    puts "  making JSON config file ..."
    set json [make_status_config_json]
    set json_file "[file normalize [pwd]]/tapasco_status.json"
    puts "  JSON configuration in $json_file: "
    puts "$json"
    if {[catch {open $json_file "w"} f]} {
      error "could not open file $json_file!"
    } else {
      puts -nonewline $f $json
      close $f
    }

    set outfile "[get_property DIRECTORY [current_project]]/statuscore.coe"
    if {[catch {exec -ignorestderr json_to_status $json_file $outfile | tee ${json_file}.log >@stdout 2>@1}]} {
      puts stderr "Building TaPaSCO status core failed, see ${json_file}.log:"
      puts stderr [read [open ${json_file}.log r]]
      error "Could not build status core."
    }
    puts "Wrote COE file to ${outfile}"

    set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} \
                         CONFIG.Load_Init_File {true}         \
                         CONFIG.EN_SAFETY_CKT {false}         \
                         CONFIG.Coe_File $outfile] [get_bd_cells -filter "NAME == ${name}_base"]
  }

  # Generate JSON configuration for the status core.
  proc make_status_config_json {} {
    platform::addressmap::reset
    puts "  getting address map ..."
    set addr [platform::get_address_map [platform::get_pe_base_address]]
    set slots [list]
    set slot_id 0
    puts "  address map = $addr"
    foreach intf [dict keys $addr] {
      if {[string match "/arch/*" "$intf"] == 1} {
        puts "  processing $intf: [dict get $addr $intf kind] ..."
        switch [dict get $addr $intf "kind"] {
          "register" {
            set kind [format "%d" [regsub {.*target_ip_([0-9][0-9]).*} $intf {\1}]]
            set kid [dict get [::tapasco::get_composition] $kind id]
            lappend slots [json::write object "Type" [json::write string "Kernel"] "SlotId" $slot_id "Kernel" $kid \
                                              "Offset" [json::write string [format "0x%016x" [expr "[dict get $addr $intf "offset"] - [::platform::get_pe_base_address]"]]]          \
                                              "Size" [json::write string [format "0x%016x" [dict get $addr $intf "range"]]]]
            incr slot_id
          }
          "memory" {
            lappend slots [json::write object "Type" [json::write string "Memory"] "SlotId" $slot_id "Kernel" 0 \
                                              "Offset" [json::write string [format "0x%016x" [expr "[dict get $addr $intf "offset"] - [::platform::get_pe_base_address]"]]] \
                                              "Size" [json::write string [format "0x%016x" [dict get $addr $intf "range"]]]]
            incr slot_id
          }
          "master" {}
          default { error "invalid kind: [dict get $addr $intf kind]" }
        }
      }
    }
    puts "  finished composition map, composing JSON ..."

    # get platform component base addresses
    set pc_bases [list]
    foreach {pc_name pc_base size} [::platform::addressmap::get_platform_component_bases] {
      puts "$pc_name, $pc_base, $size"
      set name $pc_name
      set base [expr "$pc_base - [::platform::get_platform_base_address]"]
      lappend pc_bases [json::write object "Name" [json::write string $pc_name] "Offset" [json::write string [format "0x%016x" $base]] \
                          "Size" [json::write string [format "0x%016x" $size]]]
    }
    puts "  finished address map, composing JSON ..."

    set regex {([0-9][0-9][0-9][0-9]).([0-9][0-9]*)}
    set no_intc [::platform::number_of_interrupt_controllers]
    set ts [clock seconds]

    return [json::write object \
      "Timestamp" [expr "$ts - ($ts \% 86400)"] \
      "InterruptControllers" $no_intc \
      "Versions" [json::write array \
        [json::write object "Software" [json::write string "Vivado"] "Year" [::tapasco::get_vivado_version_major] "Release" [::tapasco::get_vivado_version_minor] \
                                                                     "ExtraVersion" [json::write string [::tapasco::get_vivado_version_extra]]] \
        [json::write object "Software" [json::write string "TaPaSCo"] "Year" [regsub $regex [::tapasco::get_tapasco_version] {\1}] "Release" [regsub $regex [::tapasco::get_tapasco_version] {\2}] "ExtraVersion" [json::write string ""]] \
      ] \
      "Clocks" [json::write array \
        [json::write object "Domain" [json::write string "Host"] "Frequency" [::tapasco::get_host_frequency]] \
        [json::write object "Domain" [json::write string "Design"] "Frequency" [::tapasco::get_design_frequency]] \
        [json::write object "Domain" [json::write string "Memory"] "Frequency" [::tapasco::get_mem_frequency]] \
      ] \
      "Capabilities" [json::write object "Capabilities 0" [::tapasco::get_capabilities_flags]] \
        "Architecture" [json::write object "Base" [json::write string [format "0x%016x" [::platform::get_pe_base_address]]] \
                                       "Composition" [json::write array {*}$slots]] \
        "Platform" [json::write object "Base" [json::write string [format "0x%016x" [::platform::get_platform_base_address]]] \
                                       "Components" [json::write array {*}$pc_bases]] \
    ]
  }
}
