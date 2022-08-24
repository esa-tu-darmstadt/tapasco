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
namespace eval platform {
  set platform_dirname "sim"

  if { [::tapasco::vivado_is_newer "2018.1"] == 0 } {
    puts "Vivado [version -short] is too old to support simulation platform."
    exit 1
  }

  foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME_TCL)/platform/${platform_dirname}/plugins" "*.tcl"] {
    source -notrace $f
  }

  proc max_masters {} {
    return [list [::tapasco::get_platform_num_slots]]
  }

  proc get_pe_base_address {} {
    return 0x0
  }

  proc get_platform_base_address {} {
    return 0x0010000000
  }

  proc get_address_map {{pe_base ""}} {
    set max32 [expr "1 << 32"]
    if {$pe_base == ""} { set pe_base [get_pe_base_address] }
    puts "Computing addresses for PEs ..."
    set peam [::arch::get_address_map $pe_base]
    puts "Computing addresses for masters ..."
    foreach m [::tapasco::get_aximm_interfaces [get_bd_cells -filter "PATH !~ [::tapasco::subsystem::get arch]/*"]] {
      puts {[DEBUG] get address map foreach}
      # no M_INTC address map, because simulation does not need special interrupt handling
      # handling is done in cocotb
      switch -glob [get_property NAME $m] {
        "M_TAPASCO" { foreach {base stride range comp} [list 0x0010000000 0       0 "PLATFORM_COMPONENT_STATUS"] {} }
        "M_ARCH"    { set base "skip" }
        default     { foreach {base stride range comp} [list 0 0 0 ""] {} }
      }
      if {$base != "skip"} { set peam [addressmap::assign_address $peam $m $base $stride $range $comp] }
    }
    puts {[DEBUG] after get address map foreach}
    return $peam
  }

  # does not directly modify address map but assigning addresses here is
  # necessary because the generic address map assignment process expects
  # address maps associated with intf_PINS in Master mode instead of
  # intf_PORTS in Slave mode used by this sim platform type
  proc modify_address_map_sim {map} {
    puts $map
    set ignored [::platform::get_ignored_segments]
    set space [get_bd_addr_spaces /S_AXI]
    set intf [get_bd_intf_ports -of_objects $space]
    set segs [get_bd_addr_seg -addressables -of_objects $intf]
    set seg_i 0
    foreach seg $segs {
      if {[lsearch $ignored $seg] >= 0} {
        puts "Skipping ignored segment $seg"
      } else {
        puts "  seg: $seg"
        set sintf [get_bd_intf_pins -of_objects $seg]
        set me [dict get $map $sintf]
        puts "  address map info $me"
        set range [expr "max([dict get $me range], 4096)"]
        set offset [expr "max([dict get $me "offset"], [get_property OFFSET $sintf])"]
        set range [expr "max($range, [get_property RANGE $sintf])"]
        if {[expr "(1 << 64) == $range"]} {set range "16E"}
        create_bd_addr_seg \
          -offset $offset \
          -range $range \
          $space \
          $seg \
          [format "AM_SEG_%03d" $seg_i]
        incr seg_i
      }
    }
  }

  proc get_ignored_segments { } {
    set ignored [list]
    return $ignored
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_DDR_LOW"
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_LPS_OCM"
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_PCIE_LOW"
    lappend ignored "/host/zynqmp/SAXIGP0/HPC0_QSPI"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_DDR_LOW"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_LPS_OCM"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_PCIE_LOW"
    lappend ignored "/host/zynqmp/SAXIGP4/HP2_QSPI"
    return $ignored
  }

  proc number_of_interrupt_controllers {} {
    return 0
    set no_pes [llength [arch::get_processing_elements]]
    return [expr "$no_pes > 96 ? 4 : ($no_pes > 64 ? 3 : ($no_pes > 32 ? 2 : 1))"]
  }

  # Creates a subsystem with clock and reset generation for a list of clocks.
  # Consists of clocking wizard + reset generators with single ext. reset in.
  # @param freqs list of name frequency (MHz) pairs, e.g., [list design 100 memory 250]
  # @param name Name of the subsystem group
  # @return Subsystem group
  proc create_subsystem_clocks_and_resets {} {
    set freqs [::tapasco::get_frequencies]
    puts "Creating clock and reset subsystem ..."
    puts "  frequencies: $freqs"

    set reset_in [create_bd_pin -dir I -type rst "reset_in"]
    set clk_wiz [::tapasco::ip::create_clk_wiz "clk_wiz"]
    set_property -dict [list CONFIG.USE_LOCKED {true} CONFIG.USE_RESET {false}] $clk_wiz
    set instance [current_bd_instance .]

    # provide an external port for the locked signal
    # needed to be able to determine when simulation of the composition is stable
    # -> e.g. axi requests can only be processed after clocks have become stable
    make_bd_pins_external [get_bd_pins $clk_wiz/locked]
    current_bd_instance ..
    set_property name locked [get_bd_ports locked_0]
    current_bd_instance $instance

    set clk_mode [lindex [get_board_part_interfaces -filter { NAME =~ *sys*cl*k }] 0]

    if {$clk_mode != ""} {
      set_property CONFIG.CLK_IN1_BOARD_INTERFACE $clk_mode $clk_wiz
    } else {
      puts "Could not find a board interface for the sys clock. Trying to use processing system clock."
      set ps_clk_in [create_bd_pin -dir I -type clk "ps_clk_in"]
    }

    # check if external port already exists, re-use
    if {[get_bd_ports -quiet "/$clk_mode"] != {}} {
      puts "entered clk_mode if"
      # connect existing top-level port
      connect_bd_net [get_bd_ports "/$clk_mode"] [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $clk_wiz]
      # use PLL primitive for all but the first subsystem (MMCMs are limited)
      set_property -dict [list CONFIG.PRIMITIVE {PLL} CONFIG.USE_MIN_POWER {true}] $clk_wiz
    } {
      # apply board automation to create top-level port
      if {($clk_mode != "") && ([get_property VLNV $clk_mode] == "xilinx.com:interface:diff_clock_rtl:1.0")} {
        set cport [get_bd_intf_pins -of_objects $clk_wiz]
      } {
        set cport [get_bd_pins -filter {DIR == I} -of_objects $clk_wiz]
      }
      puts "  clk_wiz: $clk_wiz, cport: $cport"
      if {$cport != {}} {
        if {[info exists ps_clk_in]} {
          # connect ps clock in with clk_wizard
          connect_bd_net $ps_clk_in $cport
        } else {
          # apply board automation
          apply_bd_automation -rule xilinx.com:bd_rule:board -config "Board_Interface $clk_mode" $cport
          puts "board automation worked, moving on"
        }
      } {
        # last resort: try to call platform::create_clock_port
        set clk_mode "sys_clk"
        set cport [platform::create_clock_port $clk_mode]
        connect_bd_net $cport [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $clk_wiz]
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
      # get ports
      puts "current name: $name"
      if {$name == "memory"} { set name "mem" }
      set clk    [::tapasco::subsystem::get_port $name "clk"]
      set p_rstn [::tapasco::subsystem::get_port $name "rst" "peripheral" "resetn"]
      set p_rst  [::tapasco::subsystem::get_port $name "rst" "peripheral" "reset"]
      set i_rstn [::tapasco::subsystem::get_port $name "rst" "interconnect"]

      if {[expr "$j < $i"]} {
        # simply re-wire sources
        set rst_gen [get_bd_cells "[lindex $freqs $j]_rst_gen"]
        set ex_clk [::tapasco::subsystem::get_port [lindex $freqs $j] "clk"]
        puts "rst_gen = $rst_gen"
        connect_bd_net -net [get_bd_nets -boundary_type lower -of_objects $ex_clk] $clk
        connect_bd_net [get_bd_pins $rst_gen/peripheral_aresetn] $p_rstn
        connect_bd_net [get_bd_pins $rst_gen/peripheral_reset] $p_rst
        connect_bd_net [get_bd_pins $rst_gen/interconnect_aresetn] $i_rstn
      } {
        set_property -dict [list CONFIG.CLKOUT${clkn}_USED {true} CONFIG.CLKOUT${clkn}_REQUESTED_OUT_FREQ $freq] $clk_wiz
        set clkp [get_bd_pins "$clk_wiz/clk_out${clkn}"]
        set rstgen [::tapasco::ip::create_rst_gen "${name}_rst_gen"]
        connect_bd_net $clkp $clk
        connect_bd_net $reset_in [get_bd_pins "$rstgen/ext_reset_in"]
        connect_bd_net $clkp [get_bd_pins "$rstgen/slowest_sync_clk"]
        connect_bd_net [get_bd_pins "$rstgen/peripheral_reset"] $p_rst
        connect_bd_net [get_bd_pins "$rstgen/peripheral_aresetn"] $p_rstn
        connect_bd_net [get_bd_pins "$rstgen/interconnect_aresetn"] $i_rstn
        incr clkn
      }
    }
  }

  proc create_subsystem_memory {} {
    # to be implemented
  }

  # Create interrupt controller subsystem:
  # only sets the mappings, since interrupts will have a direct 1-to-1-mapping
  # to the host subsystem and will consequently be connected directly
  # to external ports
  proc create_subsystem_intc {} {
    set int_list [::tapasco::ip::get_interrupt_list]
    set int_mapping [list]
    set int_design_total 0
    foreach {name clk} $int_list {
      lappend int_mapping $int_design_total
      incr int_design_total
    }

    ::tapasco::ip::set_interrupt_mapping $int_mapping
  }


  # Creates the host subsystem containing the PS7.
  proc create_subsystem_host {} {
    puts "Creating Host/Sim subsystem ..."

    set aximm_vlnv [::tapasco::ip::get_vlnv "aximm_intf"]
    set axi_sc_vlnv [::tapasco::ip::get_vlnv "axi_sc"]
    set freqs [::tapasco::get_frequencies]
    puts "freqs: $freqs"


    set reset_in [create_bd_pin -dir O -type rst "reset_in"]
    set instance [current_bd_instance .]
    set name_external_rst "ext_reset_in"
    set external_reset_in [create_bd_pin -dir I -type rst $name_external_rst]
    connect_bd_net $reset_in $external_reset_in
    make_bd_pins_external $external_reset_in
    current_bd_instance
    set_property NAME $name_external_rst [get_bd_ports -filter "NAME == [format %s_0 $name_external_rst]"]
    current_bd_instance $instance

    if {[get_bd_pins /clocks_and_resets/ps_clk_in] != {}} {
      puts "Found pin in clock subsystem that requires a clock input from the processing system."
      set ps_clk_in [create_bd_pin -dir O -type clk "ps_clk_in"]
      set instance [current_bd_instance .]
      set name_external "ext_ps_clk_in"
      set external_ps_clk_in [create_bd_pin -dir I -type clk $name_external]
      connect_bd_net $ps_clk_in $external_ps_clk_in
      make_bd_pins_external $external_ps_clk_in
      current_bd_instance
      set_property NAME $name_external [get_bd_ports -filter "NAME == [format %s_0 $name_external]"]
      current_bd_instance $instance
    }

    set interrupts [::tapasco::ip::create_interrupt_in_ports]
    set int_outs [list]
    foreach int $interrupts {
      set int_name "ext_[get_property NAME $int]"
      set port [create_bd_pin -type INTR -dir O $int_name]
      connect_bd_net $int $port
      set instance [current_bd_instance .]
      make_bd_pins_external $port
      current_bd_instance
      set_property NAME $int_name [get_bd_ports -filter "NAME == [format %s_0 $int_name]"]
      current_bd_instance $instance
    }

    set host_aclk [tapasco::subsystem::get_port "host" "clk"]
    set design_aclk [tapasco::subsystem::get_port "design" "clk"]

    set smartconnect [create_bd_cell -type ip -vlnv $axi_sc_vlnv smartconnect_0]
    set_property -dict [list CONFIG.NUM_MI {2} CONFIG.NUM_SI {1} CONFIG.NUM_CLKS {4} CONFIG.HAS_ARESETN {0}] $smartconnect
    set m_arch [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv "M_ARCH"]
    set m_tapasco [create_bd_intf_pin -mode Master -vlnv $aximm_vlnv "M_TAPASCO"]
    connect_bd_intf_net $m_arch [get_bd_intf_pins -of_objects $smartconnect -filter {NAME == M00_AXI}]
    connect_bd_intf_net $m_tapasco [get_bd_intf_pins -of_objects $smartconnect -filter {NAME == M01_AXI}]

    set mem_aclk [tapasco::subsystem::get_port "mem" "clk"]
    set aclk0 [get_bd_pins -of_objects $smartconnect -filter {NAME == aclk}]
    set aclk1 [get_bd_pins -of_objects $smartconnect -filter {NAME == aclk1}]
    set aclk2 [get_bd_pins -of_objects $smartconnect -filter {NAME == aclk2}]
    set aclk3 [get_bd_pins -of_objects $smartconnect -filter {NAME == aclk3}]

    connect_bd_net $external_ps_clk_in $aclk0
    connect_bd_net $host_aclk $aclk1
    connect_bd_net $design_aclk $aclk2
    connect_bd_net $mem_aclk $aclk3
    set instance [current_bd_instance]
    make_bd_intf_pins_external [get_bd_intf_pins -of_object $smartconnect -filter {NAME == S00_AXI}]
    set s_axi_ext [get_bd_intf_ports -filter {NAME == S00_AXI_0}]
    set_property NAME S_AXI $s_axi_ext
    set ext_ps_clk_in [get_bd_ports -filter {NAME == ext_ps_clk_in}]
    set_property CONFIG.ASSOCIATED_BUSIF {S_AXI} $ext_ps_clk_in
    current_bd_instance $instance

    save_bd_design

  }

  # don't run synthesis and implementation, only generate new ip core
  proc __disabled__generate {} {
    global bitstreamname
    set project_dir [get_property DIRECTORY [current_project]]
    puts "project dir: $project_dir"
    ipx::package_project \
    -root_dir [get_property DIRECTORY [current_project]] \
    -vendor esa.informatik.tu-darmstadt.de \
    -library sim -taxonomy /UserIP \
    -force -generated_files -import_files
    puts "packaged project"

    ipx::create_xgui_files [ipx::current_core]
    puts "created xgui_files"
    ipx::update_checksums [ipx::current_core]
    puts "created xgui_files"
    ipx::check_integrity [ipx::current_core]
    puts "created xgui_files"
    ipx::save_core [ipx::current_core]
    puts "created xgui_files"
    update_ip_catalog -rebuild -repo_path $project_dir
    puts "created xgui_files"
    ipx::check_integrity -quiet -xrt [ipx::current_core]
    puts "created xgui_files"
    ipx::archive_core "$project_dir/../$bitstreamname.zip" [ipx::current_core]
    puts "created xgui_files"
  }
}
