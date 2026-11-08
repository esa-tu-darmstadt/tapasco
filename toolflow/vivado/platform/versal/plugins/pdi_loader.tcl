# Copyright (c) 2014-2026 Embedded Systems and Applications, TU Darmstadt.
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

# PDI-Loader: lets PEs trigger the loading of a PDI from device memory through the PLM. For every PDILoad
# master interface (pc2.uni-paderborn.de:lennart:PDILoad_rtl:1.0, common/ip/PDILoad) of a PE a PDILoader
# core (common/ip/PDILoader) is instantiated in the host subsystem and connected to the CIPS S_AXI_LPD port.
# The IPI message RAM is only reachable over the direct PL-to-PS slave ports, not over the NoC, and the PLM
# only services IPI channels up to the number of IPI instances in the design, so all of them are enabled.
#
# Properties:
#   "ipi_channel":    IPI channel 0, 1, 2, 3, 4, or 5 of the first loader (default 2), further loaders take the next ones
#   "timeout_cycles": cycles the loader waits for the PLM before reporting a timeout (default 2^30)
#   "interface":      only connect PE interfaces whose path matches *<interface> (default: all)
#   "ila":            "true" adds an AXI ILA on the LPD port (needs the Debug feature)
#
# The LPD segments have fixed addresses, so the loader's master is assigned by assign_bd_address after
# TaPaSCo's own address map was built (post-platform).

if {[tapasco::is_feature_enabled "PDI-Loader"]} {
  namespace eval pdi_loader {
    variable pdi_load_rtl "pc2.uni-paderborn.de:lennart:PDILoad_rtl:1.0"
    variable loaders [list]
    variable channels [list]

    # The PDILoad master interfaces of the PEs in the arch, optionally filtered by the "interface" property.
    proc get_requesters {} {
      variable pdi_load_rtl
      set pes [get_bd_cells -hier -filter "PATH =~ [::tapasco::subsystem::get arch]/* && TYPE == ip"]
      set filter "VLNV == $pdi_load_rtl && MODE == Master"
      set intf [tapasco::get_feature_option "PDI-Loader" "interface" -1]
      if {$intf != -1} {
        append filter " && PATH =~ *$intf"
      }
      return [lsort -dictionary [get_bd_intf_pins -quiet -of_objects $pes -filter $filter]]
    }

    # "pre-wiring": one PDILoader per requesting interface in the host subsystem, connected to it.
    proc create_loaders {{args {}}} {
      variable loaders
      variable channels
      set requesters [get_requesters]
      if {[llength $requesters] == 0} {
        error "PDI-Loader: no PE interface of type PDILoad_rtl found (packaged with the interface definition from common/ip/PDILoad?)"
      }
      set first_channel [tapasco::get_feature_option "PDI-Loader" "ipi_channel" 2]
      set timeout [tapasco::get_feature_option "PDI-Loader" "timeout_cycles" 1073741824]
      if {[expr $first_channel + [llength $requesters] - 1] > 5} {
        error "PDI-Loader: [llength $requesters] requesters from IPI channel $first_channel exceed the last usable channel 5"
      }

      set old_bd_inst [current_bd_instance .]
      current_bd_instance "/host"
      set design_aclk [tapasco::subsystem::get_port "design" "clk"]
      set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

      set i 0
      foreach req $requesters {
        set channel [expr $first_channel + $i]
        set loader [tapasco::ip::create_pdi_loader "pdi_loader_$i"]
        set_property -dict [list CONFIG.IPI_CHANNEL $channel CONFIG.TIMEOUT_CYCLES $timeout] $loader
        connect_bd_net $design_aclk [get_bd_pins $loader/aclk]
        connect_bd_net $design_aresetn [get_bd_pins $loader/aresetn]
        connect_bd_intf_net -boundary_type upper $req [get_bd_intf_pins $loader/S_PDI_LOAD]
        puts "PDI-Loader: $req -> $loader (IPI channel $channel, timeout $timeout cycles)"
        lappend loaders $loader
        lappend channels $channel
        incr i
      }

      current_bd_instance $old_bd_inst
      return $args
    }

    # "post-platform": IPI channels and S_AXI_LPD on the CIPS, the LPD connection, the fixed LPD addresses.
    proc connect_lpd {{args {}}} {
      variable loaders
      variable channels
      set old_bd_inst [current_bd_instance .]
      current_bd_instance "/host"
      set cips [get_bd_cells versal_cips_0]
      set design_aclk [tapasco::subsystem::get_port "design" "clk"]
      set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

      # All IPI instances must exist: the 2023.1 PLM sizes its IPI handling by the number of IPI instances
      # in the design and its interrupt handler only scans that many ISR bits, so a request on a higher
      # channel is dropped silently.
      set_property -dict [list CONFIG.PS_PMC_CONFIG { \
        PS_GEN_IPI0_ENABLE 1 PS_GEN_IPI0_MASTER S_AXI_GP4 \
        PS_GEN_IPI1_ENABLE 1 PS_GEN_IPI1_MASTER S_AXI_GP4 \
        PS_GEN_IPI2_ENABLE 1 PS_GEN_IPI2_MASTER S_AXI_GP4 \
        PS_GEN_IPI3_ENABLE 1 PS_GEN_IPI3_MASTER S_AXI_GP4 \
        PS_GEN_IPI4_ENABLE 1 PS_GEN_IPI4_MASTER S_AXI_GP4 \
        PS_GEN_IPI5_ENABLE 1 PS_GEN_IPI5_MASTER S_AXI_GP4 \
        PS_GEN_IPI6_ENABLE 1 PS_GEN_IPI6_MASTER S_AXI_GP4 \
        PS_USE_S_AXI_LPD 1 PS_S_AXI_LPD_DATA_WIDTH 32 \
      }] $cips
      connect_bd_net [get_bd_pins $cips/s_axi_lpd_aclk] $design_aclk

      if {[llength $loaders] == 1} {
        set lpd_master [get_bd_intf_pins [lindex $loaders 0]/M_AXI_LPD]
      } else {
        set sc [tapasco::ip::create_axi_sc "pdi_loader_sc" [llength $loaders] 1 1 true]
        connect_bd_net $design_aclk [get_bd_pins $sc/aclk]
        connect_bd_net $design_aresetn [get_bd_pins $sc/aresetn]
        set i 0
        foreach loader $loaders {
          connect_bd_intf_net [get_bd_intf_pins $loader/M_AXI_LPD] [get_bd_intf_pins $sc/[format "S%02d_AXI" $i]]
          incr i
        }
        set lpd_master [get_bd_intf_pins $sc/M00_AXI]
      }
      connect_bd_intf_net $lpd_master [get_bd_intf_pins $cips/S_AXI_LPD]

      if {[tapasco::get_feature_option "PDI-Loader" "ila" "false"] == "true"} {
        set ila [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_ila:1.2 pdi_loader_ila]
        set_property -dict [list CONFIG.C_DATA_DEPTH {32768} CONFIG.C_MON_TYPE {Interface_Monitor}] $ila
        connect_bd_intf_net [get_bd_intf_pins $ila/SLOT_0_AXI] [get_bd_intf_nets -of_objects $lpd_master]
        connect_bd_net [get_bd_pins $ila/clk] $design_aclk
        connect_bd_net [get_bd_pins $ila/resetn] $design_aresetn
      }

      # the LPD segments sit at fixed addresses; check that every loader reaches its IPI block and the message RAM
      assign_bd_address
      foreach loader $loaders channel $channels {
        set space [get_bd_addr_spaces $loader/M_AXI_LPD]
        set expected [list "psv_ipi_${channel}" [expr 0xFF330000 + $channel * 0x10000] "psv_ipi_buffer" 0xFF3F0000]
        foreach {name offset} $expected {
          set segs [get_bd_addr_segs -quiet -of_objects $space -filter "NAME =~ *${name} || NAME =~ *${name}_*"]
          if {[llength $segs] != 1 || [get_property OFFSET $segs] != $offset} {
            error "PDI-Loader: $loader does not reach $name at [format 0x%08X $offset] (found: $segs)"
          }
          puts "PDI-Loader: $loader reaches $segs"
        }
      }

      current_bd_instance $old_bd_inst
      return $args
    }

    proc write_ltx {{args {}}} {
      if {[tapasco::get_feature_option "PDI-Loader" "ila" "false"] == "true"} {
        write_debug_probes -force debug_probes.ltx
      }
      return $args
    }
  }

  tapasco::register_plugin "platform::pdi_loader::create_loaders" "pre-wiring"
  tapasco::register_plugin "platform::pdi_loader::connect_lpd"    "post-platform"
  tapasco::register_plugin "platform::pdi_loader::write_ltx"      "post-bitstream"
}
