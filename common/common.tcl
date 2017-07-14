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
  namespace export createBinaryCounter
  namespace export createClockingWizard
  namespace export createConcat
  namespace export createConstant
  namespace export createDualDMA
  namespace export createDWidthConverter
  namespace export createRegisterSlice
  namespace export createIntCtrl
  namespace export createInterconnect
  namespace export createMIG
  namespace export createOLEDController
  namespace export createPCIeBridge
  namespace export createPCIeIntrCtrl
  namespace export createMSIXIntrCtrl
  namespace export createProtocolConverter
  namespace export createSlice
  namespace export createSystemCache
  namespace export createZynqBFM
  namespace export createZynqPS
  namespace export get_board_preset
  namespace export get_composition
  namespace export get_design_frequency
  namespace export get_design_period
  namespace export get_number_of_processors
  namespace export get_speed_grade
  namespace export get_wns_from_timing_report

  namespace export create_interconnect_tree

  # check if we're running inside Vivado
  if {[llength [info commands version]] > 0} {
    # source IP catalog VLNVs for the current Vivado version
    set cip [format "$::env(TAPASCO_HOME)/common/common_%s.tcl" [version -short]]
    if {! [file exists $cip]} {
      puts "Could not find $cip, Vivado [version -short] is not supported yet!"
      exit 1
    } {
      source $cip
    }
  } {
    puts "Skipping IP catalog."
  }

  # Returns the Tapasco version.
  proc get_tapasco_version {} {
    return "2017.1"
  }

  # Instantiates an AXI4 Interconnect IP.
  # @param name Name of the instance.
  # @param no_slaves Number of AXI4 Slave interfaces.
  # @param no_masters Number of AXI4 Master interfaces.
  # @return bd_cell of the instance.
  proc createInterconnect {name no_slaves no_masters} {
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

  # Instantiates a Zynq-7000 Processing System IP core.
  # @param name Name of the instance (default: ps7).
  # @param preset Name of board preset to apply (default: tapasco::get_board_preset).
  # @param freq_mhz FCLK_0 frequency in MHz (default: tapasco::get_design_frequency).
  # @return bd_cell of the instance.
  proc createZynqPS {{name ps7} {preset [tapasco::get_board_preset]} {freq_mhz [tapasco::get_design_frequency]}} {
    variable stdcomps
    puts "Creating Zynq-7000 series IP core ..."
    puts "  VLNV: [dict get $stdcomps ps vlnv]"
    puts "  Preset: $preset"
    puts "  FCLK0 : $freq_mhz"

    set ps [create_bd_cell -type ip -vlnv [dict get $stdcomps ps vlnv] $name]
    if {$preset != {} && $preset != ""} {
      set_property -dict [list CONFIG.preset $preset] $ps
      apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" } $ps
    } {
      apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "0" Master "Disable" Slave "Disable" } $ps
    }
    return $ps
  }

  # Instantiates a Zynq-7000 Processing System IP BFM simulation core.
  # @param name Name of the instance (default: ps7).
  # @param preset Name of board preset to apply (default: tapasco::get_board_preset).
  # @param freq_mhz FCLK_0 frequency in MHz (default: tapasco::get_design_frequency).
  # @return bd_cell of the instance.
  proc createZynqBFM {{name ps7} {preset [tapasco::get_board_preset]} {freq_mhz [tapasco::get_design_frequency]}} {
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
  proc createConcat {name inputs} {
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
  proc createSlice {name width bit} {
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
  proc createConstant {name width value} {
    variable stdcomps
    puts "Creating xlconstant $name with $width-bit width and value $value ..."
    puts "  VLNV: [dict get $stdcomps xlconst vlnv]"

    set xlconst [create_bd_cell -type ip -vlnv [dict get $stdcomps xlconst vlnv] $name]
    set_property -dict [list CONFIG.CONST_WIDTH $width CONFIG.CONST_VAL $value] $xlconst
    return $xlconst
  }

  # Instantiates an AXI4 Interrupt Controller IP core.
  # @param name Name of the instance (default: axi_intc).
  # @return bd_cell of the instance.
  proc createIntCtrl {{name axi_intc}} {
    variable stdcomps
    puts "Creating interrupt control $name ..."
    puts "  VLNV: [dict get $stdcomps axi_irqc vlnv]"

    set irqc [create_bd_cell -type ip -vlnv [dict get $stdcomps axi_irqc vlnv] $name]
    # activate edge-sensitive interrupts
    set_property -dict [list CONFIG.C_KIND_OF_INTR.VALUE_SRC USER] $irqc
    set_property -dict [list CONFIG.C_KIND_OF_INTR {0xFFFFFFFF}] $irqc
    # set_property -dict [list CONFIG.C_EN_CASCADE_MODE {1} CONFIG.C_CASCADE_MASTER {1}] $irqc
    return $irqc
  }

  # Instantiates binary counter IP core.
  # @param name Name of the instance.
  # @param output_width Bit width of the counter.
  # @return bd_cell of the instance.
  proc createBinaryCounter {name width} {
    variable stdcomps
    puts "Creating $width-bits binary counter ..."
    puts "  VLNV: [dict get $stdcomps bincnt vlnv]"

    set bincnt [create_bd_cell -type ip -vlnv [dict get $stdcomps bincnt vlnv] $name]
    # set bit-width
    set_property -dict [list CONFIG.Output_Width $width CONFIG.Restrict_Count {false}] $bincnt
    return $bincnt
  }

  # Instantiates Dual DMA core.
  # @param name Name of the instance.
  proc createDualDMA {name} {
    variable stdcomps
    puts "Creating dual DMA core ..."
    puts "  VLNV: [dict get $stdcomps dualdma vlnv]"

    set dd [create_bd_cell -type ip -vlnv [dict get $stdcomps dualdma vlnv] $name]
    set_property -dict [list \
      CONFIG.C_M32_AXI_BURST_LEN {64} \
      CONFIG.C_M32_AXI_DATA_WIDTH {512} \
      CONFIG.C_M64_AXI_BURST_LEN {128} \
      CONFIG.C_M64_AXI_DATA_WIDTH {256} \
      CONFIG.DATA_FIFO_DEPTH {16} \
      CONFIG.M32_IS_ASYNC {1} \
      CONFIG.M32_READ_MAX_REQ {8} \
      CONFIG.M32_WRITE_MAX_REQ {8} \
      CONFIG.M64_READ_MAX_REQ {8} \
      CONFIG.M64_WRITE_MAX_REQ {8} \
    ] $dd
    # read XDC file
    #set folder [format "%s/common/ip/dual_dma_1.0" $::env(TAPASCO_HOME)]
    # [get_property IP_DIR [get_ips [get_property CONFIG.Component_Name $dd]]]
    #set xdc ${folder}/dual.xdc
    #read_xdc -cells "*[get_property NAME $dd]" $xdc
    return $dd
  }

  # Instantiates a MSIX interrupt controller.
  # @param name Name of the instance.
  proc createMSIXIntrCtrl {name} {
    variable stdcomps
    puts "Creating MSIX Interrupt Controller ..."
    puts "  VLNV: [dict get $stdcomps msix_intr_ctrl vlnv]"

    set ic [create_bd_cell -type ip -vlnv [dict get $stdcomps msix_intr_ctrl vlnv] $name]
    return $ic
  }

  # Instantiates a performance counter controller for the zedboard OLED display.
  # @param name Name of the instance.
  proc createOLEDController {name} {
    variable stdcomps
    set composition [get_composition]
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
    set xdc "$::env(TAPASCO_HOME)/common/ip/oled_pc/constraints/oled.xdc"
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

  # Instantiates a processor reset generator.
  # @param name Name of the instance.
  proc createResetGen {name} {
    variable stdcomps
    puts "Creating Reset Generator ..."
    puts "  VLNV: [dict get $stdcomps rst_gen vlnv]"

    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps rst_gen vlnv] $name]
    return $inst
  }

  # Instantiates an AXI BFM core.
  # @param name Name of the instance.
  proc createAxiBFM {name} {
    variable stdcomps
    puts "Creating AXI BFM core ..."
    puts "  VLNV: [dict get $stdcomps axi_bfm vlnv]"

    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps axi_bfm vlnv] $name]
    return $inst
  }

  # Instantiates an AXI-MM full to lite stripper (assumes no bursts etc.).
  # @param name Name of the instance.
  proc createMmToLite {name} {
    variable stdcomps
    puts "Creating AXI full to lite stripper ..."
    puts "  VLNV: [dict get $stdcomps mm_to_lite vlnv]"

    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps mm_to_lite vlnv] $name]
    set_property -dict [list CONFIG.C_S_AXI_ID_WIDTH {32}] $inst
    return $inst
  }

  # Instantiates an AXI System Cache.
  # @param name Name of the instance.
  proc createSystemCache {name {num_ports 3} {size 262144} {num_sets 2}} {
    variable stdcomps
    puts "Creating AXI System Cache ..."
    puts "  VLNV: [dict get $stdcomps system_cache vlnv]"
    puts "  ports: $num_ports"
    puts "  size: $size B"
    puts "  number sets: $num_sets"

    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps system_cache vlnv] $name]
    set_property -dict [list \
      CONFIG.C_CACHE_SIZE $size \
      CONFIG.C_M_AXI_THREAD_ID_WIDTH {6} \
      CONFIG.C_NUM_GENERIC_PORTS $num_ports \
      CONFIG.C_NUM_OPTIMIZED_PORTS {0} \
      CONFIG.C_NUM_SETS $num_sets \
    ] $inst
    return $inst
  }

  # Instantiates a TPC status core.
  # @param name Name of the instance.
  # @param ids  List of kernel IDs.
  proc createTapascoStatus {name {ids {}}} {
    variable stdcomps
    puts "Creating TPC Status ..."
    puts "  VLNV: [dict get $stdcomps tapasco_status vlnv]"
    puts "  IDs : $ids"

    # check if ids are given, otherwise fetch automatically
    if {[llength $ids] > 0} {
      set c $ids
    } {
      set c [list]
      set composition [tapasco::get_composition]
      set no_kinds [llength [dict keys $composition]]
      for {set i 0} {$i < $no_kinds} {incr i} {
        set no_inst [dict get $composition $i count]
        for {set j 0} {$j < $no_inst} {incr j} {
          lappend c [dict get $composition $i id]
        }
      }
    }

    # create the IP core
    set inst [create_bd_cell -type ip -vlnv [dict get $stdcomps tapasco_status vlnv] $name]
    # make properties list
    set props [list]
    set slot 0
    foreach i $c {
      puts "  slot #$slot = $i"
      if {$slot < 128} {
        lappend props "[format CONFIG.C_SLOT_KERNEL_ID_%d [expr $slot + 1]]" "$i"
      }
      incr slot
    }
    # get version strings
    set vversion [split [version -short] {.}]
    set tversion [split [tapasco::get_tapasco_version] {.}]

    lappend props "CONFIG.C_INTC_COUNT" "[expr [llength $c] > 96 ? 4 : ([llength $c] > 64 ? 3 : ([llength $c] > 32 ? 2 : 1))]"
    lappend props "CONFIG.C_GEN_TS" "[clock seconds]"
    lappend props "CONFIG.C_VIVADO_VERSION" [format "0x%04x%04x" [expr [lindex $vversion 0]] [expr [lindex $vversion 1]]]
    lappend props "CONFIG.C_TAPASCO_VERSION" [format "0x%04x%04x" [expr [lindex $tversion 0]] [expr [lindex $tversion 1]]]
    lappend props "CONFIG.C_HOST_CLK_MHZ" [format "%d" [tapasco::get_host_frequency]]
    lappend props "CONFIG.C_MEM_CLK_MHZ" [format "%d" [tapasco::get_mem_frequency]]
    lappend props "CONFIG.C_DESIGN_CLK_MHZ" [format "%d" [tapasco::get_design_frequency]]

    puts "  properties: $props"
    set_property -dict $props $inst
    return $inst
  }

  # Instantiates an AXI protocol converter.
  # @param name Name of the instance.
  # @param from Protocol on slave side (default: AXI4LITE)
  # @param to   Protocol on master side (default: AXI4)
  proc createProtocolConverter {name {from "AXI4LITE"} {to "AXI4"}} {
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
  proc createDWidthConverter {name {from "256"} {to "64"}} {
    variable stdcomps
    puts "Creating AXI Datawidth converter $name $from -> $to ..."
    set vlnv [dict get $stdcomps dwidth_conv vlnv]
    puts "  VLNV: $vlnv"

    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    set_property -dict [list CCONFIG.SI_DATA_WIDTH $from CONFIG.MI_DATA_WIDTH $to] $inst
    return $inst
  }

  proc createRegisterSlice {name} {
    variable stdcomps
    puts "Creating AXI Register Slice $name"
    set vlnv [dict get $stdcomps axi_reg_slice vlnv]
    puts "  VLNV: $vlnv"

    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    return $inst
  }

  # Instantiates a MIG core.
  # @param name Name of the instance.
  # @return block design cell.
  proc createMIG {name} {
    variable stdcomps
    puts "Creating MIG cores $name ..."
    set vlnv [dict get $stdcomps mig_core vlnv]
    puts "  VLNV: $vlnv"

    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    return $inst
  }

  # Instantiates a PCIe 3.0 AXI bridge core.
  # @param name Name of the instance.
  # @return block design cell.
  proc createPCIeBridge {name} {
    variable stdcomps
    puts "Creating PCIe Bridge core $name ..."
    set vlnv [dict get $stdcomps axi_pcie3_0 vlnv]
    puts "  VLNV: $vlnv"

    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    return $inst
  }

  # Instantiates a clocking wizard.
  # @param name Name of the instance.
  # @return block design cell.
  proc createClockingWizard {name} {
    variable stdcomps
    puts "Creating Clocking Wizard $name ..."
    set vlnv [dict get $stdcomps clk_wiz]
    puts "  VLNV: $vlnv"

    set inst [create_bd_cell -type ip -vlnv $vlnv $name]
    return $inst
  }

  # Returns the interface pin groups for all AXI MM interfaces on cell.
  # @param cell the object whose interfaces shall be returned
  # @parma mode filters interfaces by mode (default: Master)
  # @return list of interface pins
  proc get_aximm_interfaces {cell {mode "Master"}} {
    return [get_bd_intf_pins -of_objects $cell -filter "VLNV =~ xilinx.com:interface:aximm_rtl:* && MODE == $mode"]
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

  # Returns a list of configured features for the Platform.
  proc get_platform_features {} {
    global platformfeatures
    if {[info exists platformfeatures]} { return [dict keys $platformfeatures] } { return [dict] }
  }

  # Returns a dictionary with the configuration of given Platform feature.
  proc get_platform_feature {feature} {
    global platformfeatures
    if {[info exists platformfeatures] && [dict exists $platformfeatures $feature]} {
      return [dict get $platformfeatures $feature]
    } else {
      return [dict create]
    }
  }

  # Returns true, if given feature is configured and enabled.
  proc is_platform_feature_enabled {feature} {
    global platformfeatures
    if {[info exists platformfeatures]} {
      if {[dict exists $platformfeatures $feature]} {
        if {[dict get $platformfeatures $feature "enabled"] == "true"} {
          return true
        }
      }
    }
    return false
  }

  # Returns a list of configured features for the Architecture.
  proc get_architecture_features {} {
    global architecturefeatures
    if {[info exists architecturefeatures]} { return [dict keys $architectureFeatures] } { return [dict create] }
  }

  # Returns a dictionary with the configuration of given Architecture feature.
  proc get_architecture_feature {feature} {
    global architecturefeatures
    if {[info exists architecturefeatures]} { return [dict get $architecturefeatures $feature] } { return [dict] }
  }

  # Returns true, if given feature is configured and enabled.
  proc is_architecture_feature_enabled {feature} {
    global architecturefeatures
    if {[info exists architecturefeatures]} {
      if {[dict exists $architecturefeatures $feature]} {
        if {[dict get $architecturefeatures $feature "enabled"] == "true"} {
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
      set bic [createInterconnect "bic" 1 1]
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
        set nic [createInterconnect [format "ic_%03d" $ic_n] [expr "$masters ? $rest_ports : 1"] [expr "$masters ? 1 : $rest_ports"]]
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
        # activate deep packet mode FIFO
        set_property -dict [list CONFIG.M00_HAS_DATA_FIFO {2}] $curr_ics
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

  # Creates a subsystem with clock and reset generation for a list of clocks.
  # Consists of clocking wizard + reset generators with single ext. reset in.
  # @param freqs list of name frequency (MHz) pairs, e.g., [list design 100 memory 250]
  # @param name Name of the subsystem group
  # @return Subsystem group
  proc create_subsystem_clocks_and_resets {{freqs {}} {name ClockResets}} {
    if {$freqs == {}} { set freqs [get_frequencies] }
    puts "Creating clock and reset subsystem ..."
    puts "  frequencies: $freqs"
    set instance [current_bd_instance .]
    set group [create_bd_cell -type hier $name]
    current_bd_instance $group

    set reset_in [create_bd_pin -dir I -type rst "reset_in"]
    set clk [createClockingWizard "clk_wiz"]
    set_property -dict [list CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false} CONFIG.NUM_OUT_CLKS [expr "[llength $freqs] / 2"]] $clk
    set clk_mode "sys_diff_clock"

    if {[catch {set_property CONFIG.CLK_IN1_BOARD_INTERFACE {sys_diff_clock} $clk}]} {
      puts "  sys_diff_clock is not supported, trying sys_clock instead"
      set clk_mode "sys_clock"
    }
    # check if external port already exists, re-use
    if {[catch [get_bd_ports "/$clk_mode"]]} {
      # connect existing top-level port
      connect_bd_net [get_bd_ports "/$clk_mode"] [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $clk]
      # use PLL primitive for all but the first subsystem (MMCMs are limited)
      set_property -dict [list CONFIG.PRIMITIVE {PLL} CONFIG.USE_MIN_POWER {true}] $clk
    } {
      # apply board automation to create top-level port
      if {$clk_mode == "sys_diff_clock"} {
        set cport [get_bd_intf_pins -of_objects $clk]
      } {
        set cport [get_bd_pins -filter {DIR == I} -of_objects $clk]
      }
      puts "  clk: $clk, cport: $cport"
      if {$cport != {}} {
        # apply board automation
        apply_bd_automation -rule xilinx.com:bd_rule:board -config "Board_Interface $clk_mode" $cport
        puts "board automation worked, moving on"
      } {
        # last resort: try to call platform::create_clock_port
        set clk_mode "sys_clk"
        set cport [platform::create_clock_port $clk_mode]
        connect_bd_net $cport [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $clk]
      }
    }

    for {set i 0; set clkn 1} {$i < [llength $freqs]} {incr i 2} {
      set name [lindex $freqs $i]
      set freq [lindex $freqs [expr $i + 1]]
      #set clkn [expr "$i / 2 + 1"]
      puts "  instantiating clock: $name @ $freq MHz"
      for {set j 0} {$j < $i} {incr j 2} {
        if {[lindex $freqs [expr $j + 1]] == $freq} {
          puts "    $name is same frequency as [lindex $freqs $j], re-using"
          break
        }
      }
      # create ports
      set port [create_bd_pin -dir O -type clk ${name}_aclk]
      set p_rst [create_bd_pin -dir O -type rst "${name}_peripheral_aresetn"]
      set i_rst [create_bd_pin -dir O -type rst "${name}_interconnect_aresetn"]

      if {[expr "$j < $i"]} {
        # simply re-wire sources
        foreach p [list "aclk" "interconnect_aresetn" "peripheral_aresetn"] dst [list $port $i_rst $p_rst] {
          puts "  j = $j,  [lindex $freqs $j]_${p}"
          set src [get_bd_pins -filter {DIR == O} -of_objects [get_bd_nets -boundary_type lower -of_objects [get_bd_pins "[lindex $freqs $j]_${p}"]]]
          connect_bd_net $src $dst
        }
      } {
        set_property -dict [list CONFIG.CLKOUT${clkn}_USED {true} CONFIG.CLKOUT${clkn}_REQUESTED_OUT_FREQ $freq] $clk
        set clkp [get_bd_pins "$clk/clk_out${clkn}"]
        set rstgen [createResetGen "${name}_rst_gen"]
        connect_bd_net $clkp $port
        connect_bd_net $reset_in [get_bd_pins "$rstgen/ext_reset_in"]
        connect_bd_net $clkp [get_bd_pins "$rstgen/slowest_sync_clk"]
        connect_bd_net [get_bd_pins "$rstgen/peripheral_aresetn"] $p_rst
        connect_bd_net [get_bd_pins "$rstgen/interconnect_aresetn"] $i_rst
        incr clkn
      }
    }

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
}
