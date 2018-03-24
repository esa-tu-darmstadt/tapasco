namespace eval ::tapasco::ip {
  set stdcomps [dict create]

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
  proc create_bin_cnt {name width} {
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

  # Instantiates Dual DMA core.
  # @param name Name of the instance.
  proc create_dualdma {name} {
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

  # Instantiates a performance counter controller for the zedboard OLED display.
  # @param name Name of the instance.
  proc create_oled_ctrl {name} {
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
      CONFIG.C_M_AXI_THREAD_ID_WIDTH {6} \
      CONFIG.C_NUM_GENERIC_PORTS $num_ports \
      CONFIG.C_NUM_OPTIMIZED_PORTS {0} \
      CONFIG.C_NUM_SETS $num_sets \
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

  # Instantiates a TaPaSCo status core.
  # @param name Name of the instance.
  # @param ids  List of kernel IDs.
  proc create_tapasco_status {name {ids {}}} {
    set vlnv [tapasco::ip::get_vlnv "tapasco_status"]
    puts "Creating custom status core ..."
    puts "  VLNV: $vlnv"
    puts "  IDs : $ids"
    puts "  sourcing JSON lib ..."
    source -notrace "$::env(TAPASCO_HOME)/common/json_write.tcl"
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

    # generate core
    set old_pwd [pwd]
    set jar "$::env(TAPASCO_HOME)/common/ip/tapasco_status/tapasco-status.jar"
    set cache "[get_property DIRECTORY [current_project]]/../user_ip/tapasco-status"
    if {[catch {exec -ignorestderr java -jar $jar $cache $json_file | tee ${json_file}.log >@stdout 2>@1}]} {
      puts stderr "Building TaPaSCO status core failed, see ${json_file}.log:"
      puts stderr [read [open ${json_file}.log r]]
      error "Could not build status core."
    }
    cd $old_pwd

    # parse log and add custom IP path to IP_REPO_PATHS
    set log [read [open ${json_file}.log r]]
    set ip_path [regsub {.*Finished, IP Core is located in ([^ \n\t]*).*} $log {\1}]
    puts "  Path to custom IP: $ip_path"
    update_ip_catalog -rebuild

    puts "  done!"
    # create the IP core
    return [create_bd_cell -type ip -vlnv $vlnv $name]
  }

  # Generate JSON configuration for the status core.
  proc make_status_config_json {} {
    platform::addressmap::reset
    puts "  getting adddress map ..."
    set addr [platform::get_address_map [platform::get_pe_base_address]]
    set slots [list]
    set slot_id 0
    puts "  address map = $addr"
    foreach intf [dict keys $addr] {
      puts "  processing $intf: [dict get $addr $intf kind] ..."
      switch [dict get $addr $intf "kind"] {
        "register" {
          set kind [format "%d" [regsub {.*target_ip_([0-9][0-9]).*} $intf {\1}]]
          set kid [dict get [::tapasco::get_composition] $kind id]
          lappend slots [json::write object "Type" [json::write string "Kernel"] "SlotId" $slot_id "Kernel" $kid]
          incr slot_id
        }
        "memory" {
          lappend slots [json::write object "Type" [json::write string "Memory"] "SlotId" $slot_id "Bytes" [format "%d" [dict get $addr $intf "range"]]]
          incr slot_id
        }
        "master" {}
        default { error "invalid kind: [dict get $addr $intf kind]" }
      }
    }
    puts "  finished composition map, composing JSON ..."

    # get PE base addresses
    set pe_bases [list]
    foreach pe_base [::platform::addressmap::get_processing_element_bases] {
      lappend pe_bases [json::write object "Address" \
        [json::write string [format "0x%08x" $pe_base]]
      ]
    }

    # get platform component base addresses
    set pc_bases [list]
    foreach pc_base [::platform::addressmap::get_platform_component_bases] {
      lappend pc_bases [json::write object "Address" \
        [json::write string [format "0x%08x" $pc_base]] \
      ]
    }
    puts "  finished address map, composing JSON ..."

    set regex {([0-9][0-9][0-9][0-9]).([0-9][0-9]*)}
    set no_intc [::platform::number_of_interrupt_controllers]
    set ts [clock seconds]

    return [json::write object \
      "Composition" [json::write array {*}$slots] \
      "Timestamp" [expr "$ts - ($ts \% 86400)"] \
      "Interrupt Controllers" $no_intc \
      "Versions" [json::write array \
        [json::write object "Software" [json::write string "Vivado"] "Year" [regsub $regex [version -short] {\1}] "Release" [regsub $regex [version -short] {\2}]] \
        [json::write object "Software" [json::write string "TaPaSCo"] "Year" [regsub $regex [::tapasco::get_tapasco_version] {\1}] "Release" [regsub $regex [::tapasco::get_tapasco_version] {\2}]] \
      ] \
      "Clocks" [json::write array \
        [json::write object "Domain" [json::write string "Host"] "Frequency" [::tapasco::get_host_frequency]] \
        [json::write object "Domain" [json::write string "Design"] "Frequency" [::tapasco::get_design_frequency]] \
        [json::write object "Domain" [json::write string "Memory"] "Frequency" [::tapasco::get_mem_frequency]] \
      ] \
      "Capabilities" [json::write object "Capabilities 0" [::tapasco::get_capabilities_flags]] \
      "BaseAddresses" [json::write object \
        "Architecture" [json::write array {*}$pe_bases] \
        "Platform" [json::write array {*}$pc_bases] \
      ] \
    ]
  }
}
