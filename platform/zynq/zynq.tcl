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
# @file		zynq.tcl
# @brief	Zynq-7000 platform implementation: For simulation, there is an extra AXI 
#               master connected to HP3 (to simulate loading of data). Up to 16 instances
#               of AXI Interrupt Controllers are instantiated, depending on the number
#               interrupt sources returned by the architecture.
# @author	J. Korinth, TU Darmstadt (jk@esa.tu-darmstadt.de)
#
namespace eval platform {
  namespace eval zynq {
    namespace export create
    namespace export generate
    namespace export max_masters
  
    # check if TAPASCO_HOME env var is set
    if {![info exists ::env(TAPASCO_HOME)]} {
      puts "Could not find TPC root directory, please set environment variable 'TAPASCO_HOME'."
      exit 1
    }
    # check if DPI server lib env var is set
    if {[tapasco::get_generate_mode] == "sim"} {
      puts "Simulation currently not supported."
      exit 1
    }
    # scan plugin directory
    foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/zynq/plugins" "*.tcl"] {
      source -notrace $f
    }
  
    proc max_masters {} {
      return [list 64 64]
    }
  
    # Setup the clock network.
    proc platform_connect_clock {ps} {
      puts "Connecting clocks ..."
  
      set clk_inputs [get_bd_pins -of_objects [get_bd_cells] -filter { TYPE == "clk" && DIR == "I" }]
      switch [tapasco::get_generate_mode] {
        "sim" {
          puts "  simulation mode, creating external port to drive PS_CLK" 
          set clk_port [create_bd_port -dir "I" -type CLK clk]
          connect_bd_net $clk_port [get_bd_pins -of_objects $ps -filter { NAME == "PS_CLK" }]
          connect_bd_net [get_bd_pins -of_objects $ps -filter { NAME == "FCLK_CLK0" }] $clk_inputs
        }
        "bit" {
          puts "  bitstream mode, connecting to FCLK_CLK0 port of PS7"
          set clk_inputs [get_bd_pins -of_objects [get_bd_cells] -filter { TYPE == "clk" && DIR == "I" }]
          connect_bd_net [get_bd_pins -of_objects $ps -filter { NAME == "FCLK_CLK0" }] $clk_inputs
        }
        default {
          puts "Don't know how to connect clock for mode '$mode'."
          exit 1
        }
      }
    }
  
    # Setup the reset network.
    proc platform_connect_reset {ps rst_gen} {
      puts "Connecting resets ..."
  
      set ics [get_bd_cells -filter "VLNV =~ *axi_interconnect*"]
      set ic_resets [get_bd_pins -of_objects $ics -filter { TYPE == "rst" && NAME == "ARESETN" }]
      lappend ic_resets [get_bd_pins Threadpool/interconnect_aresetn]
      set periph_resets [get_bd_pins -of_objects $ics -filter { TYPE == "rst" && NAME != "ARESETN" && DIR == "I" }]
      lappend periph_resets [get_bd_pins -filter { TYPE == "rst" && DIR == "I" && NAME != "ARESETN" } -of_objects [get_bd_cells -filter { NAME =~ axi_intc* }]]
      lappend periph_resets [get_bd_pins Threadpool/peripheral_aresetn]
      lappend periph_resets [get_bd_pins "tapasco_status/s00_axi_aresetn"]
      puts "ic_resets = $ic_resets"
      puts "periph_resets = $periph_resets"
  
      switch [tapasco::get_generate_mode] {
        "sim" {
          puts "  simulation mode, creating active low external port to drive PS and rst_gen resets"
          set rst_port [create_bd_port -dir "I" -type RST rst]
          set ext_resets [get_bd_pins -of_objects $rst_gen -filter { NAME == "ext_reset_in" }]
          lappend ext_resets [get_bd_pins -of_objects $ps -filter { NAME == "PS_SRSTB" || NAME == "PS_PORB" }]
          connect_bd_net $rst_port $ext_resets
  
          connect_bd_net [get_bd_pins -of_objects $rst_gen -filter { NAME == "interconnect_aresetn" }] $ic_resets
          connect_bd_net [get_bd_pins -of_objects $rst_gen -filter { NAME == "peripheral_aresetn" }] $periph_resets
        }
        "bit" {
          puts "  bitstream mode, connecting to FCLK_RESET0_N on PS7"
          connect_bd_net [get_bd_pins -of_objects $ps -filter { NAME == "FCLK_RESET0_N" }] [get_bd_pins -of_objects $rst_gen -filter { NAME == "ext_reset_in" }]
          connect_bd_net [get_bd_pins -of_objects $rst_gen -filter { NAME == "interconnect_aresetn" }] $ic_resets
          connect_bd_net [get_bd_pins -of_objects $rst_gen -filter { NAME == "peripheral_aresetn" }] $periph_resets
        }
        default {
          puts "Don't know how to connect reset for mode '$mode'."
          exit 1
        }
      }
    }
  
    # Setup interrupts.
    proc platform_connect_interrupts {irqs ps} {
      puts "Connecting [llength $irqs] interrupts .."
  
      # create interrupt controllers and connect them to GP1
      set intcs [list]
      set cc [tapasco::createConcat "intc_concat" [llength $irqs]]
      set i 0
      foreach irq $irqs {
        set intc [tapasco::createIntCtrl [format "axi_intc_%02d" $i]]
        lappend intcs $intc
        connect_bd_net -boundary_type upper $irq [get_bd_pins -of $intc -filter {NAME=="intr"}]
        connect_bd_net -boundary_type upper [get_bd_pins -of $intc -filter {NAME=="irq"}] [get_bd_pins -of $cc -filter "NAME == [format "In%d" $i]"]
        incr i
      }
  
      set intcic [tapasco::createInterconnect "axi_intc_ic" 1 [llength $intcs]]
      set i 0
      foreach intc $intcs {
        set slave [get_bd_intf_pins -of $intc -filter { MODE == "Slave" }]
        set master [get_bd_intf_pins -of $intcic -filter "NAME == [format "M%02d_AXI" $i]"]
        puts "Connecting $master to $slave ..."
        connect_bd_intf_net -boundary_type upper $master $slave
        incr i
      }
  
      # connect concat to the host
      connect_bd_net [get_bd_pins -of $cc -filter { DIR == "O" }] [get_bd_pins -of $ps -filter { NAME == "IRQ_F2P" }]
      # connect interconnect to the host at GP1
      connect_bd_intf_net [get_bd_intf_pins -of $ps -filter {NAME=="M_AXI_GP1"}] [get_bd_intf_pins -of $intcic -filter {MODE=="Slave"}]
      return $intcs
    }
  
    # Creates the optional OLED controller indicating interrupts.
    # @param ps Processing System instance
    proc create_subsystem_oled {name irqs} {
      # number of INTC's
      set no_intcs [llength $irqs]
      # make new group for OLED
      set instance [current_bd_instance .]
      set group [create_bd_cell -type hier $name]
      current_bd_instance $group
  
      # create OLED controller
      set oled_ctrl [tapasco::createOLEDController oled_ctrl]
  
      # create ports
      set clk [create_bd_pin -type "clk" -dir I "aclk"]
      set rst [create_bd_pin -type "rst" -dir I "peripheral_aresetn"]
      set op_cc [tapasco::createConcat "op_cc" $no_intcs]
      connect_bd_net [get_bd_pins -of_objects $op_cc -filter { DIR == "O" }] [get_bd_pins $oled_ctrl/intr]
      for {set i 0} {$i < $no_intcs} {incr i} {
        connect_bd_net [lindex $irqs $i] [get_bd_pins "$op_cc/In$i"]
      }
  
      # connect clock port
      connect_bd_net $clk [get_bd_pins -of_objects $oled_ctrl -filter { TYPE == "clk" && DIR == "I" }]
  
      # connect reset
      connect_bd_net $rst [get_bd_pins $oled_ctrl/rst_n]
  
      # create external port 'oled'
      set op [create_bd_intf_port -mode "master" -vlnv "esa.cs.tu-darmstadt.de:user:oled_rtl:1.0" "oled"]
      connect_bd_intf_net [get_bd_intf_pins -of_objects $oled_ctrl] $op
  
      current_bd_instance $instance
      return $group
    }
  
    # Create TPC status information core.
    # @param TPC composition dict.
    proc createTapascoStatus {composition} {
      set c [list]
      set no_kinds [llength [dict keys $composition]]
      for {set i 0} {$i < $no_kinds} {incr i} {
        set no_inst [dict get $composition $i count]
        for {set j 0} {$j < $no_inst} {incr j} {
          lappend c [dict get $composition $i id]
        }
      }
      set tapasco_status [tapasco::createTapascoStatus "tapasco_status" $c]
      return $tapasco_status
    }
  
    # Create interrupt controller subsystem:
    # Consists of AXI_INTC IP cores (as many as required), which are connected by an internal
    # AXI Interconnect (S_AXI port) and to the Zynq interrupt lines.
    # @param irqs List of the interrupts from the threadpool.
    # @param ps_irq_in interrupt port of host
    proc create_subsystem_interrupts {irqs ps_irq_in} {
      puts "Connecting [llength $irqs] interrupts .."
      puts "  irqs = $irqs"
  
      # create hierarchical group
      set group [create_bd_cell -type hier "InterruptControl"]
      set instance [current_bd_instance]
      current_bd_instance $group
  
      # create hierarchical ports
      set s_axi [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI"]
      set aclk [create_bd_pin -type "clk" -dir I "aclk"]
      set ic_aresetn [create_bd_pin -type "rst" -dir I "interconnect_aresetn"]
      set p_aresetn [create_bd_pin -type "rst" -dir I "peripheral_aresetn"]
      set irq_out [create_bd_pin -type "intr" -dir O -to [expr "[llength $irqs] - 1"] "irq_out"]
  
      # create interrupt controllers and connect them to GP1
      set intcs [list]
      foreach irq $irqs {
        set intc [tapasco::createIntCtrl [format "axi_intc_%02d" [llength $intcs]]]
        connect_bd_net $irq [get_bd_pins -of $intc -filter {NAME=="intr"}]
        lappend intcs $intc
      }
  
      # concatenate interrupts and connect them to port
      set int_cc [tapasco::createConcat "int_cc" [llength $irqs]]
      for {set i 0} {$i < [llength $irqs]} {incr i} {
        connect_bd_net [get_bd_pins "[lindex $intcs $i]/irq"] [get_bd_pins "$int_cc/In$i"]
      }
      connect_bd_net [get_bd_pins "$int_cc/dout"] $irq_out
      connect_bd_net $irq_out $ps_irq_in
  
      set intcic [tapasco::createInterconnect "axi_intc_ic" 1 [llength $intcs]]
      set i 0
      foreach intc $intcs {
        set slave [get_bd_intf_pins -of $intc -filter { MODE == "Slave" }]
        set master [get_bd_intf_pins -of $intcic -filter "NAME == [format "M%02d_AXI" $i]"]
        puts "Connecting $master to $slave ..."
        connect_bd_intf_net -boundary_type upper $master $slave
        incr i
      }
  
      # connect internal clocks
      connect_bd_net -net intc_clock_net $aclk [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == "clk" && DIR == "I"}]
      # connect internal interconnect resets
      set ic_resets [get_bd_pins -of_objects [get_bd_cells -filter {VLNV =~ "*:axi_interconnect:*"}] -filter {NAME == "ARESETN"}]
      connect_bd_net -net intc_ic_reset_net $ic_aresetn $ic_resets
      # connect internal peripheral resets
      set p_resets [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN"}]
      connect_bd_net -net intc_p_reset_net $p_aresetn $p_resets
  
      # connect S_AXI
      connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $intcic -filter {NAME == "S00_AXI"}]
  
      current_bd_instance $instance
      return $group
    }

    # Creates the host subsystem containing the PS7.
    proc create_subsystem_host {} {
      puts "Creating Host/PS7 subsystem ..."
  
      # create hierarchical group
      set group [create_bd_cell -type hier "Host"]
      set instance [current_bd_instance .]
      current_bd_instance $group
  
      # create hierarchical ports
      set s_acp [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI_ACP"]
      set s_hp0 [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI_HP0"]
      set s_hp2 [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI_HP2"]
      set m_gp0 [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_AXI_GP0"]
      set m_gp1 [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_AXI_GP1"]
      set mem_aclk [create_bd_pin -type "clk" -dir "I" "memory_aclk"]
      set mem_p_arstn [create_bd_pin -type "rst" -dir "I" "memory_peripheral_aresetn"]
      set mem_ic_arstn [create_bd_pin -type "rst" -dir "I" "memory_interconnect_aresetn"]
      set host_aclk [create_bd_pin -type "clk" -dir "I" "host_aclk"]
      set host_p_arstn [create_bd_pin -type "rst" -dir "I" "host_peripheral_aresetn"]
      set host_ic_arstn [create_bd_pin -type "rst" -dir "I" "host_interconnect_aresetn"]
      set fclk0_aclk [create_bd_pin -type "clk" -dir "O" "ps_aclk"]
      set fclk0_aresetn [create_bd_pin -type "rst" -dir "O" "ps_resetn"]
  
      # generate PS7 instance
      switch [tapasco::get_generate_mode] {
        "sim" {
          set ps [tapasco::createZynqBFM "ps7" [tapasco::get_board_preset] [tapasco::get_design_frequency]]
        }
        "bit" {
          set ps [tapasco::createZynqPS "ps7" [tapasco::get_board_preset] [tapasco::get_design_frequency]]
        }
        default {
          puts "ERROR: unknown mode $mode."
          exit 1
        }
      }
      # activate ACP, HP0, HP2 and GP0/1 (+ FCLK1 @10MHz)
      set_property -dict [list \
        CONFIG.preset [tapasco::get_board_preset] \
        CONFIG.PCW_USE_M_AXI_GP0 			{1} \
        CONFIG.PCW_USE_M_AXI_GP1 			{1} \
        CONFIG.PCW_USE_S_AXI_HP0 			{1} \
        CONFIG.PCW_USE_S_AXI_HP1 			{0} \
        CONFIG.PCW_USE_S_AXI_HP2 			{1} \
        CONFIG.PCW_USE_S_AXI_HP3 			{0} \
        CONFIG.PCW_USE_S_AXI_ACP 			{1} \
        CONFIG.PCW_USE_S_AXI_GP0 			{0} \
        CONFIG.PCW_USE_S_AXI_GP1 			{0} \
        CONFIG.PCW_S_AXI_HP0_DATA_WIDTH 		{64} \
        CONFIG.PCW_S_AXI_HP2_DATA_WIDTH 		{64} \
        CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL 		{1} \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 		[tapasco::get_design_frequency] \
        CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 		{10} \
        CONFIG.PCW_USE_FABRIC_INTERRUPT 		{1} \
        CONFIG.PCW_IRQ_F2P_INTR 			{1} \
        CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 		{0} \
        CONFIG.PCW_EN_CLK1_PORT 			{1} ] $ps
  
      # connect masters
      connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_GP0"] $m_gp0
      connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_GP1"] $m_gp1
  
      # connect slaves
      connect_bd_intf_net $s_acp [get_bd_intf_pins "$ps/S_AXI_ACP"]
      connect_bd_intf_net $s_hp0 [get_bd_intf_pins "$ps/S_AXI_HP0"]
      connect_bd_intf_net $s_hp2 [get_bd_intf_pins "$ps/S_AXI_HP2"]

      # forward host clock and reset
      connect_bd_net [get_bd_pins "$ps/FCLK_CLK0"] $fclk0_aclk
      connect_bd_net [get_bd_pins "$ps/FCLK_RESET0_N"] $fclk0_aresetn

      # connect memory slaves to memory clock and reset
      connect_bd_net $mem_aclk [get_bd_pins -of_objects $ps -filter {NAME =~ "S*ACLK"}]
      connect_bd_net $host_aclk [get_bd_pins -of_objects $ps -filter {NAME =~ "M*ACLK"}]
  
      current_bd_instance $instance
      return $group
    }
  
    # Creates the reset subsystem consisting of reset generators for the clocks.
    # @param clocks list of clock signals for which to generate AXI reset signals
    # @param ext_reset asynchronous reset signal to use as input
    proc create_subsystem_reset {clocks ext_reset} {
      puts "Creating Reset subsystem for $clocks and reset $ext_reset..."
  
      # create hierarchical group
      set group [create_bd_cell -type hier "Resets"]
      set instance [current_bd_instance]
      current_bd_instance $group
  
      # create reset generators and ports
      set ext_reset_ins [list]
      for {set i 0} {$i < [llength $clocks]} {incr i} {
        set clock [lindex $clocks $i]
        set rst_gen [tapasco::createResetGen "rst_gen_$i"]
        set cn [get_property "NAME" [get_bd_pins $clock]]
        connect_bd_net $clock [get_bd_pins "$rst_gen/slowest_sync_clk"] 
        lappend ext_reset_ins [get_bd_pins "$rst_gen/ext_reset_in"]
        set pp_port [create_bd_pin -type "rst" -dir "O" "${cn}_peripheral_aresetn"]
        set ic_port [create_bd_pin -type "rst" -dir "O" "${cn}_interconnect_aresetn"]
        connect_bd_net [get_bd_pins "$rst_gen/peripheral_aresetn"] $pp_port
        connect_bd_net [get_bd_pins "$rst_gen/interconnect_aresetn"] $ic_port
      }
  
      # connect external reset source
      connect_bd_net $ext_reset $ext_reset_ins
      current_bd_instance $instance
      return $group
    }
  
    proc platform_address_map {} {
      set host_addr_space [get_bd_addr_space "/Host/ps7/Data"]
      # connect interrupt controllers
      set intcs [lsort [get_bd_addr_segs -of_objects [get_bd_cells /InterruptControl/axi_intc_0*]]]
      set offset 0x81800000
      for {set i 0} {$i < [llength $intcs]} {incr i; incr offset 0x10000} {
        create_bd_addr_seg -range 64K -offset $offset $host_addr_space [lindex $intcs $i] "INTC_SEG$i"
      }
  
      # connect TPC status core
      set status_segs [get_bd_addr_segs -of_objects [get_bd_cells "tapasco_status"]]
      set offset 0x77770000
      set i 0
      foreach s $status_segs {
        create_bd_addr_seg -range 4K -offset $offset $host_addr_space $s "STATUS_SEG$i"
        incr i
        incr offset 0x1000
      }
  
      # connect user IP: slaves
      set usrs [lsort [get_bd_addr_segs "/Threadpool/*"]]
      set offset 0x43C00000
      for {set i 0} {$i < [llength $usrs]} {incr i; incr offset 0x10000} {
        create_bd_addr_seg -range 64K -offset $offset $host_addr_space [lindex $usrs $i] "USR_SEG$i"
      }
  
      # connect user IP: masters
      set pes [lsort [arch::get_processing_elements]]
      foreach pe $pes {
        set masters [tapasco::get_aximm_interfaces $pe]
        foreach m $masters {
          set slaves [find_bd_objs -relation addressable_slave $m]
          set spaces [get_bd_addr_spaces $pe/* -filter { NAME =~ "*m_axi*" || NAME =~ "*M_AXI*" }]
          foreach u $spaces {
            create_bd_addr_seg -range [get_property RANGE $u] -offset 0 $u [get_bd_addr_segs $slaves/*] "SEG_$u"
          }
        }
      }
    }
  
    # Platform API: Entry point for Platform instantiation.
    proc create {} {
      # create Zynq host subsystem
      set ss_host [create_subsystem_host]

      # create clocks and resets
      set mem_freq 200
      if {[tapasco::get_speed_grade] > -2} {
        puts "  speed grade: [tapasco::get_speed_grade], reducing mem speed to 158 MHz"
        set mem_freq 158
      }
      set ss_cnr [tapasco::create_subsystem_clocks_and_resets [list \
          "host" [tapasco::get_design_frequency] \
          "design" [tapasco::get_design_frequency] \
          "memory" $mem_freq]]
      connect_bd_net [get_bd_pins -filter {TYPE == rst && DIR == O} -of_objects $ss_host] \
          [get_bd_pins -filter {TYPE == rst && DIR == I} -of_objects $ss_cnr]

      foreach clk [list "host" "design" "memory"] {
        foreach p [list "aclk" "interconnect_aresetn" "peripheral_aresetn"] {
          connect_bd_net [get_bd_pins "$ss_cnr/${clk}_${p}"] [get_bd_pins "Threadpool/${clk}_${p}"]
        }
      }
  
      # create interrupt subsystem
      set ss_int [create_subsystem_interrupts [arch::get_irqs] [get_bd_pins "$ss_host/ps7/IRQ_F2P"]]
      connect_bd_intf_net [get_bd_intf_pins "$ss_host/M_AXI_GP1"] [get_bd_intf_pins "$ss_int/S_AXI"]
      connect_bd_net [get_bd_pins "$ss_cnr/host_aclk"] [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $ss_int]
      connect_bd_net [get_bd_pins "$ss_cnr/host_interconnect_aresetn"] [get_bd_pins "$ss_int/interconnect_aresetn"]
      connect_bd_net [get_bd_pins "$ss_cnr/host_peripheral_aresetn"] [get_bd_pins "$ss_int/peripheral_aresetn"]
  
      # create status core
      set tapasco_status [createTapascoStatus [tapasco::get_composition]]
      set gp0_out [tapasco::create_interconnect_tree "gp0_out" 2 false]
      connect_bd_intf_net [get_bd_intf_pins "$ss_host/M_AXI_GP0"] [get_bd_intf_pins "$gp0_out/S000_AXI"]
      connect_bd_intf_net [get_bd_intf_pins "$gp0_out/M000_AXI"] [get_bd_intf_pins "/Threadpool/S_AXI"]
      connect_bd_intf_net [get_bd_intf_pins "$gp0_out/M001_AXI"] [get_bd_intf_pins "$tapasco_status/S00_AXI"]
      connect_bd_net [get_bd_pins "$ss_cnr/host_aclk"] \
          [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $tapasco_status] \
          [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $gp0_out]
      connect_bd_net [get_bd_pins "$ss_cnr/host_peripheral_aresetn"] \
          [get_bd_pins -filter {TYPE == rst && DIR == I} -of_objects $tapasco_status] \
          [get_bd_pins -filter {DIR == I && NAME =~ "*peripheral_aresetn"} -of_objects $gp0_out]
      connect_bd_net [get_bd_pins "$ss_cnr/host_interconnect_aresetn"] \
          [get_bd_pins -filter {DIR == I && NAME =~ "*interconnect_aresetn"} -of_objects $gp0_out]

      foreach clk [list "host" "memory"] {
        foreach p [list "aclk" "interconnect_aresetn" "peripheral_aresetn"] {
          connect_bd_net [get_bd_pins "$ss_cnr/${clk}_${p}"] [get_bd_pins "Host/${clk}_${p}"]
        }
      }

      # connect design masters to memory
      set mem_ms [arch::get_masters]
      set mem_intfs [list HP0 HP2]
      if {[llength $mem_ms] > 2} {
        error "ERROR: Currently only up to three masters can be connected to memory!"
        exit 1
      }
      for {set i 0} {$i < [llength $mem_ms]} {incr i} {
        set m [lindex $mem_ms $i]
        set intf [lindex $mem_intfs $i]
        puts "Connecting master $m to memory interface S_AXI_$intf ..."
        connect_bd_intf_net $m [get_bd_intf_pins "$ss_host/S_AXI_$intf"]
      }
  
      # call plugins
      tapasco::call_plugins "post-bd"

      platform_address_map
      validate_bd_design
      save_bd_design
    }
   
    proc get_debug_nets {} {
      set host_prefix "system_i/Host"
      set ps_prefix "system_i/Host/ps7"
      set int_prefix "system_i/InterruptControl_"
      set tp_prefix "system_i/Threadpool_"
  
      set ret [list \
          "$host_prefix/irq_out*" \
  \
  	"${host_prefix}_M_AXI_GP0_RDATA*" \
  	"${host_prefix}_M_AXI_GP0_WDATA*" \
  	"${host_prefix}_M_AXI_GP0_ARADDR*" \
  	"${host_prefix}_M_AXI_GP0_AWADDR*" \
  	"${host_prefix}_M_AXI_GP0_AWVALID" \
  	"${host_prefix}_M_AXI_GP0_AWREADY" \
  	"${host_prefix}_M_AXI_GP0_ARVALID" \
  	"${host_prefix}_M_AXI_GP0_ARREADY" \
  	"${host_prefix}_M_AXI_GP0_WVALID" \
  	"${host_prefix}_M_AXI_GP0_WREADY" \
  	"${host_prefix}_M_AXI_GP0_RVALID" \
  	"${host_prefix}_M_AXI_GP0_RREADY" \
  \
  	"${host_prefix}_M_AXI_GP1_RDATA*" \
  	"${host_prefix}_M_AXI_GP1_WDATA*" \
  	"${host_prefix}_M_AXI_GP1_ARADDR*" \
  	"${host_prefix}_M_AXI_GP1_AWADDR*" \
  	"${host_prefix}_M_AXI_GP1_AWVALID" \
  	"${host_prefix}_M_AXI_GP1_AWREADY" \
  	"${host_prefix}_M_AXI_GP1_ARVALID" \
  	"${host_prefix}_M_AXI_GP1_ARREADY" \
  	"${host_prefix}_M_AXI_GP1_WVALID" \
  	"${host_prefix}_M_AXI_GP1_WREADY" \
  	"${host_prefix}_M_AXI_GP1_RVALID" \
  	"${host_prefix}_M_AXI_GP1_RREADY" \
        ]
  
      if {[llength [get_nets "${ps_prefix}/S_AXI_HP0_RDATA*"]] > 0} {
        lappend ret [list \
  	"${ps_prefix}/S_AXI_HP0_RDATA*" \
  	"${ps_prefix}/S_AXI_HP0_WDATA*" \
  	"${ps_prefix}/S_AXI_HP0_ARADDR*" \
  	"${ps_prefix}/S_AXI_HP0_AWADDR*" \
  	"${ps_prefix}/S_AXI_HP0_AWVALID" \
  	"${ps_prefix}/S_AXI_HP0_AWREADY" \
  	"${ps_prefix}/S_AXI_HP0_ARVALID" \
  	"${ps_prefix}/S_AXI_HP0_ARREADY" \
  	"${ps_prefix}/S_AXI_HP0_WVALID" \
  	"${ps_prefix}/S_AXI_HP0_WREADY" \
  	"${ps_prefix}/S_AXI_HP0_WSTRB*" \
  	"${ps_prefix}/S_AXI_HP0_RVALID" \
  	"${ps_prefix}/S_AXI_HP0_RREADY" \
  	"${ps_prefix}/S_AXI_HP0_ARBURST*" \
  	"${ps_prefix}/S_AXI_HP0_AWBURST*" \
  	"${ps_prefix}/S_AXI_HP0_ARLEN*" \
  	"${ps_prefix}/S_AXI_HP0_AWLEN*" \
  	"${ps_prefix}/S_AXI_HP0_WLAST" \
  	"${ps_prefix}/S_AXI_HP0_RLAST" \
       ]
     }
  
      if {[llength [get_nets "${ps_prefix}/S_AXI_HP2_RDATA*"]] > 0} {
        lappend ret [list \
  	"${ps_prefix}/S_AXI_HP2_RDATA*" \
  	"${ps_prefix}/S_AXI_HP2_WDATA*" \
  	"${ps_prefix}/S_AXI_HP2_ARADDR*" \
  	"${ps_prefix}/S_AXI_HP2_AWADDR*" \
  	"${ps_prefix}/S_AXI_HP2_AWVALID" \
  	"${ps_prefix}/S_AXI_HP2_AWREADY" \
  	"${ps_prefix}/S_AXI_HP2_ARVALID" \
  	"${ps_prefix}/S_AXI_HP2_ARREADY" \
  	"${ps_prefix}/S_AXI_HP2_WVALID" \
  	"${ps_prefix}/S_AXI_HP2_WREADY" \
  	"${ps_prefix}/S_AXI_HP2_WSTRB*" \
  	"${ps_prefix}/S_AXI_HP2_RVALID" \
  	"${ps_prefix}/S_AXI_HP2_RREADY" \
  	"${ps_prefix}/S_AXI_HP2_ARBURST*" \
  	"${ps_prefix}/S_AXI_HP2_AWBURST*" \
  	"${ps_prefix}/S_AXI_HP2_ARLEN*" \
  	"${ps_prefix}/S_AXI_HP2_AWLEN*" \
  	"${ps_prefix}/S_AXI_HP2_WLAST" \
  	"${ps_prefix}/S_AXI_HP2_RLAST" \
        ]
      }
  
      if {[llength [get_nets "${ps_prefix}/S_AXI_ACP_RDATA*"]] > 0} {
        lappend ret [list \
  	"${ps_prefix}/S_AXI_ACP_RDATA*" \
  	"${ps_prefix}/S_AXI_ACP_WDATA*" \
  	"${ps_prefix}/S_AXI_ACP_ARADDR*" \
  	"${ps_prefix}/S_AXI_ACP_AWADDR*" \
  	"${ps_prefix}/S_AXI_ACP_AWVALID" \
  	"${ps_prefix}/S_AXI_ACP_AWREADY" \
  	"${ps_prefix}/S_AXI_ACP_ARVALID" \
  	"${ps_prefix}/S_AXI_ACP_ARREADY" \
  	"${ps_prefix}/S_AXI_ACP_WVALID" \
  	"${ps_prefix}/S_AXI_ACP_WREADY" \
  	"${ps_prefix}/S_AXI_ACP_WSTRB*" \
  	"${ps_prefix}/S_AXI_ACP_RVALID" \
  	"${ps_prefix}/S_AXI_ACP_RREADY" \
  	"${ps_prefix}/S_AXI_ACP_ARBURST*" \
  	"${ps_prefix}/S_AXI_ACP_AWBURST*" \
  	"${ps_prefix}/S_AXI_ACP_ARLEN*" \
  	"${ps_prefix}/S_AXI_ACP_AWLEN*" \
  	"${ps_prefix}/S_AXI_ACP_WLAST" \
  	"${ps_prefix}/S_AXI_ACP_RLAST" \
        ]
      }
      return $ret
    }
  
    # Platform API: Main entry point to generate bitstream or simulation environement.
    proc generate {} {
      global bitstreamname
      # perform some action on the design
      switch [tapasco::get_generate_mode] {
        "sim" {
          # prepare ModelSim simulation
          update_compile_order -fileset sim_1
          set_property SOURCE_SET sources_1 [get_filesets sim_1]
          import_files -fileset sim_1 -norecurse [tapasco::get_platform_header]
          import_files -fileset sim_1 -norecurse [tapasco::get_sim_module]
          update_compile_order -fileset sim_1
          # Disabling source management mode.  This is to allow the top design properties to be set without GUI intervention.
          set_property source_mgmt_mode None [current_project]
          set_property top tb [get_filesets sim_1]
          # Re-enabling previously disabled source management mode.
          set_property source_mgmt_mode All [current_project]
          update_compile_order -fileset sim_1

          # generate simulation scripts
          launch_simulation -scripts_only
          # patch scripts: console mode only, use DPI
          [exec sed -i {s+bin_path/vsim+bin_path/vsim -c -keepstdout -sv_lib \$LIBPLATFORM_SERVER_LIB+} [pwd]/sim/sim.sim/sim_1/behav/simulate.sh]
          [exec sed -i {s+^vsim+vsim -sv_lib $::env(LIBPLATFORM_SERVER_LIB)+} [pwd]/sim/sim.sim/sim_1/behav/tb_simulate.do]
          cd [pwd]/sim/sim.sim/sim_1/behav
          if {[catch {exec >@stdout 2>@stderr [pwd]/compile.sh}] == 0} {
            if {[catch {exec >@stdout 2>@stderr [pwd]/elaborate.sh}] == 0} {
              [exec >@stdout 2>@stderr [pwd]/simulate.sh]
            } {}
          } {}
        }
        "bit" {
          set jobs [tapasco::get_number_of_processors]
          puts "  using $jobs parallel jobs"

          # generate bitstream from given design and report utilization / timing closure
          generate_target all [get_files system.bd]
          set synth_run [get_runs synth_1]
          #set_property FLOW {Vivado Synthesis 2015} $synth_run
          #set_property strategy Flow_PerfOptimized_High $synth_run
          current_run $synth_run
          launch_runs -jobs $jobs $synth_run
          wait_on_run $synth_run
          open_run $synth_run

          # call plugins
          tapasco::call_plugins "post-synth"

          set impl_run [get_runs impl_1]
          #set_property FLOW {Vivado Implementation 2015} $impl_run
          current_run $impl_run
          launch_runs -jobs $jobs -to_step route_design $impl_run
          wait_on_run $impl_run
          open_run $impl_run

          # call plugins
          tapasco::call_plugins "post-impl"

          report_timing_summary -file timing.txt -warn_on_violation
          report_utilization -file utilization.txt
          report_utilization -file utilization_userlogic.txt -cells [get_cells -hierarchical -filter {NAME =~ *target_ip_*}]
          report_power -file power.txt
          if {[get_property PROGRESS $impl_run] != "100%"} {
            error "ERROR: impl failed!"
          }
          write_bitstream -force "${bitstreamname}.bit"
        }
        default {
          puts "Don't know what to do for mode '$mode'."
          exit 1
        }
      }
    }
  }
}
