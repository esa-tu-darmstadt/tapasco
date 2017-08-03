#
# Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
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
# @file		zynqmp.tcl
# @brief	MPSoC platform implementation: Up to 16 instances of AXI Interrupt Controllers
#         are instantiated, depending on the number interrupt sources returned by the architecture.
# @author	Jaco A. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
#
namespace eval platform {
  namespace eval zynqmp {
    namespace export create
    namespace export max_masters

    # check if TAPASCO_HOME env var is set
    if {![info exists ::env(TAPASCO_HOME)]} {
      puts "Could not find TAPASCO root directory, please set environment variable 'TAPASCO_HOME'."
      exit 1
    }
    # scan plugin directory
    foreach f [glob -nocomplain -directory "$::env(TAPASCO_HOME)/platform/zynqmp/plugins" "*.tcl"] {
      source -notrace $f
    }

    proc max_masters {} {
      return [list 64 64]
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
    # @param irqs List of the interrupts from the uArch.
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
      set aresetn [create_bd_pin -type "rst" -dir I "peripheral_aresetn"]
      set irq_out [create_bd_pin -type "intr" -dir O -to [expr "[llength $irqs] - 1"] "irq_out"]

      # create interrupt controllers and connect them to HPM1 FPD
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

      set intcic [tapasco::createSmartConnect "axi_intc_ic" 1 [llength $intcs]]
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
      # connect internal resets
      set p_resets [get_bd_pins -of_objects [get_bd_cells] -filter {TYPE == rst && DIR == I && NAME != "ARESETN"}]
      connect_bd_net -net intc_p_reset_net $aresetn $p_resets

      # connect S_AXI
      connect_bd_intf_net $s_axi [get_bd_intf_pins -of_objects $intcic -filter {NAME == "S00_AXI"}]

      current_bd_instance $instance
      return $group
    }

    # Creates the host subsystem containing the PS7.
    proc create_subsystem_host {} {
      puts "Creating Host/MPSoC subsystem ..."

      # create hierarchical group
      set group [create_bd_cell -type hier "Host"]
      set instance [current_bd_instance .]
      current_bd_instance $group

      # create hierarchical ports
      set s_hp0 [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI_HP0"]
      set s_hp2 [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AXI_HP2"]
      set m_gp0 [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_AXI_GP0"]
      set m_gp1 [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_AXI_GP1"]
      set mem_aclk [create_bd_pin -type "clk" -dir "I" "memory_aclk"]
      set host_aclk [create_bd_pin -type "clk" -dir "I" "host_aclk"]
      set pl_clk0 [create_bd_pin -type "clk" -dir "O" "ps_aclk"]
      set pl_resetn0 [create_bd_pin -type "rst" -dir "O" "ps_resetn"]

      # generate PS MPSoC instance. Default values are fine
      set ps [tapasco::createMPSoCPS "zynqmp" [tapasco::get_board_preset] [tapasco::get_design_frequency]]

      # Use non-coherent AXI slaves and enable IRQs
      set_property -dict [list CONFIG.PSU__TRACE__PERIPHERAL__ENABLE {0} \
      CONFIG.PSU__USE__M_AXI_GP0 {1} \
      CONFIG.PSU__USE__M_AXI_GP1 {1} \
      CONFIG.PSU__USE__S_AXI_GP2 {1} \
      CONFIG.PSU__USE__S_AXI_GP4 {1} \
      CONFIG.PSU__USE__IRQ0 {1} \
      ] $ps

      # connect masters
      connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_HPM0_FPD"] $m_gp0
      connect_bd_intf_net [get_bd_intf_pins "$ps/M_AXI_HPM1_FPD"] $m_gp1

      # connect slaves
      connect_bd_intf_net $s_hp0 [get_bd_intf_pins "$ps/S_AXI_HP0_FPD"]
      connect_bd_intf_net $s_hp2 [get_bd_intf_pins "$ps/S_AXI_HP2_FPD"]

      # forward host clock and reset
      connect_bd_net [get_bd_pins "$ps/pl_clk0"] $pl_clk0
      connect_bd_net [get_bd_pins "$ps/pl_resetn0"] $pl_resetn0

      # connect memory slaves to memory clock and reset
      connect_bd_net $mem_aclk [get_bd_pins -of_objects $ps -filter {NAME =~ "s*aclk"}]
      connect_bd_net $host_aclk [get_bd_pins -of_objects $ps -filter {NAME =~ "m*aclk"}]

      # Add dummy XLConcat to fix errors with Vivados bus width propagation
      set dummyConcat [tapasco::createConcat "dummyConcat" 1]
      connect_bd_net [get_bd_pins dummyConcat/dout] [get_bd_pins zynqmp/pl_ps_irq0]

      current_bd_instance $instance
      return $group
    }

    proc platform_address_map {} {
      puts "Generating host address map ..."
      set host_addr_space [get_bd_addr_space "/Host/zynqmp/Data"]
      # connect interrupt controllers
      set intcs [lsort [get_bd_addr_segs -of_objects [get_bd_cells /InterruptControl/axi_intc_0*]]]
      set offset 0x00B0000000
      for {set i 0} {$i < [llength $intcs]} {incr i; incr offset 0x10000} {
        puts [format "  INTC at 0x%08x" $offset]
        create_bd_addr_seg -range 64K -offset $offset $host_addr_space [lindex $intcs $i] "INTC_SEG$i"
      }

      # connect TPC status core
      set status_segs [get_bd_addr_segs -of_objects [get_bd_cells "tapasco_status"]]
      set offset 0x00A0000000
      set i 0
      foreach s $status_segs {
        puts [format "  status at 0x%08x" $offset]
        create_bd_addr_seg -range 4K -offset $offset $host_addr_space $s "STATUS_SEG$i"
        incr i
        incr offset 0x1000
      }

      # connect user IP: slaves
      set pes [lsort [arch::get_processing_elements]]
      set offset 0x00A1000000
      set pen 0
      foreach pe $pes {
        set usrs [lsort [get_bd_addr_segs $pe/*]]
        for {set i 0} {$i < [llength $usrs]} {incr i; incr offset 0x10000} {
          puts [format "  PE $pe ([get_property VLNV $pe]) at 0x%08x of $host_addr_space" $offset]
          create_bd_addr_seg -range 64K -offset $offset $host_addr_space [lindex $usrs $i] "USR_${pen}_SEG$i"
        }
        incr pen
      }

      # connect user IP: masters
      foreach pe $pes {
        puts "  processing PE $pe ([get_property VLNV $pe]) ..."
        set masters [tapasco::get_aximm_interfaces $pe]
        puts "    number of masters: [llength $masters] ($masters)"
        foreach m $masters {
          set spaces [get_bd_addr_spaces -of_objects $m]
          puts "    master $m spaces: $spaces"
          set slaves [find_bd_objs -relation addressable_slave $m]
          puts "    master $m slaves: $slaves"
          set sn 0
          foreach space $spaces {
            foreach s $slaves {
              puts "    mapping $s in $m:$space"
              create_bd_addr_seg -range [get_property RANGE $space] -offset 0 \
                $spaces \
                [get_bd_addr_segs $s/*] \
                "SEG_${m}_${s}_${sn}"
           }
           incr sn
          }
        }
      }
    }

    # Platform API: Entry point for Platform instantiation.
    proc create {} {
      # create Zynq host subsystem
      set ss_host [create_subsystem_host]

      # create clocks and resets
      set ss_cnr [tapasco::create_subsystem_clocks_and_resets {} ClockResets user_si570_sysclk]
      connect_bd_net [get_bd_pins -filter {TYPE == rst && DIR == O} -of_objects $ss_host] \
          [get_bd_pins -filter {TYPE == rst && DIR == I} -of_objects $ss_cnr]

      foreach clk [list "host" "design" "memory"] {
        foreach p [list "aclk" "interconnect_aresetn" "peripheral_aresetn"] {
          connect_bd_net [get_bd_pins "$ss_cnr/${clk}_${p}"] [get_bd_pins "uArch/${clk}_${p}"]
        }
      }

      # create interrupt subsystem
      set ss_int [create_subsystem_interrupts [arch::get_irqs] [get_bd_pins "$ss_host/dummyConcat/In0"]]
      connect_bd_intf_net [get_bd_intf_pins "$ss_host/M_AXI_GP1"] [get_bd_intf_pins "$ss_int/S_AXI"]
      connect_bd_net [get_bd_pins "$ss_cnr/host_aclk"] [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $ss_int]
      connect_bd_net [get_bd_pins "$ss_cnr/host_peripheral_aresetn"] [get_bd_pins -filter {TYPE == rst && DIR == I} -of_objects $ss_int]

      # create status core
      set tapasco_status [createTapascoStatus [tapasco::get_composition]]
      set gp0_out [tapasco::createSmartConnect "gp0_out" 1 2]
      connect_bd_intf_net [get_bd_intf_pins "$ss_host/M_AXI_GP0"] [get_bd_intf_pins "$gp0_out/S00_AXI"]
      connect_bd_intf_net [get_bd_intf_pins "$gp0_out/M00_AXI"] [get_bd_intf_pins "/uArch/S_AXI"]
      connect_bd_intf_net [get_bd_intf_pins "$gp0_out/M01_AXI"] [get_bd_intf_pins "$tapasco_status/s00_axi"]
      connect_bd_net [get_bd_pins "$ss_cnr/host_aclk"] \
          [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $tapasco_status] \
          [get_bd_pins -filter {TYPE == clk && DIR == I} -of_objects $gp0_out]
      connect_bd_net [get_bd_pins "$ss_cnr/host_peripheral_aresetn"] [get_bd_pins -filter {TYPE == rst && DIR == I} -of_objects $tapasco_status]

      foreach clk [list "host" "memory"] {
        connect_bd_net [get_bd_pins "$ss_cnr/${clk}_aclk"] [get_bd_pins "Host/${clk}_aclk"]
      }

      # connect design masters to memory
      set mem_ms [arch::get_masters]
      set mem_intfs [list HP0 HP2]
      if {[llength $mem_ms] > 2} {
        error "ERROR: Currently only up to two masters can be connected to memory!"
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

      puts "Generating address map ..."
      platform_address_map
      puts "Validating design ..."
      validate_bd_design
      puts "Done! Saving ..."
      save_bd_design
    }
  }
}
