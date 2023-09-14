# Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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

if {[tapasco::is_feature_enabled "AI-Engine"]} {
  # add the AI engine cell to the block design
  proc create_custom_subsystem_aie {{args {}}} {
    set aie_clk [create_bd_pin -type "clk" -dir "O" "aie_clk"]
    set axi_aie [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_AIE"]

    set design_aclk [tapasco::subsystem::get_port "design" "clk"]
    set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]

    # name for ai engine needs to be exactly like this for xsa export
    set aie [create_bd_cell -type ip -vlnv xilinx.com:ip:ai_engine:2.0 ai_engine_0]

    set aie_core_freq [tapasco::get_feature_option "AI-Engine" "freq" -1]
    if {$aie_core_freq != -1} {
      puts "Setting AI Engine core frequency to $aie_core_freq"
      set_property CONFIG.AIE_CORE_REF_CTRL_FREQMHZ $aie_core_freq $aie
    }

    connect_bd_net [get_bd_pins $aie/s00_axi_aclk] $aie_clk
    connect_bd_intf_net $axi_aie [get_bd_intf_pins $aie/S00_AXI]

    # prepare ADF
    set prjdir [get_property DIRECTORY [current_project]]
    set swpath "$prjdir/adf/sw"
    exec mkdir -p $swpath
    set adf [tapasco::get_feature_option "AI-Engine" "adf" libadf.a]
    set aieprj "$prjdir/adf/system.aieprj"
    set aiecfg "$prjdir/adf/aie_cfgraph.xml"
    set olddir [pwd]
    cd $prjdir/adf
    exec ar x $adf
    cd $olddir
    exec objcopy -O binary --set-section-flags .aie.archive=alloc -j .aie.archive $prjdir/adf/hw.o $aieprj -I plugin
    exec objcopy -O binary --set-section-flags .aie.cfgraph=alloc -j .aie.cfgraph $prjdir/adf/hw.o $aiecfg -I plugin

    # do some xml parsing, a DOM parsing library would help
    set cf [open $aiecfg r]
    set cfgdata [read $cf]
    close $cf
    set maxis 0
    set saxis 0
    foreach line [split $cfgdata "\n"] {
      if {[regexp {blockPort=\"(\w*).*compPort=\"(\w*).*paddedWidth=\"(\d*).*isRegistered=\"(\w*)} $line linematch blockport compport width registered] > 0} {
        dict set ports $blockport port $compport
        dict set ports $blockport width [expr $width/8]
        dict set ports $blockport registered $registered
      } elseif {[regexp {direction=\"(\w*).*name=\"(\w*).*portType=\"(\w*)} $line linematch direction name type] > 0} {
        dict set ports $name type $type
        dict set ports $name direction $direction
        if {$direction == "out"} {
          incr maxis
        } {
          incr saxis
        }
      }
    }

    set_property -dict [list  \
      CONFIG.NUM_MI_AXIS $maxis \
      CONFIG.NUM_SI_AXIS $saxis \
      CONFIG.NUM_MI_AXI {0} \
      CONFIG.NUM_CLKS {1} \
      CONFIG.C_EN_EXT_RST {1}] $aie
    connect_bd_net [get_bd_pins $aie/aclk0] $design_aclk
    connect_bd_net [get_bd_pins $aie/aresetn0] $design_aresetn
    set_property CONFIG.ASSOCIATED_BUSIF {} [get_bd_pins $aie/aclk0]

    # configure AIE ports from dict
    foreach portname [dict keys $ports] {
      dict with ports $portname {
        set_property -dict [list \
          CONFIG.TDATA_NUM_BYTES $width \
          CONFIG.IS_REGISTERED $registered \
          HDL_ATTRIBUTE.ME_ANNOTATION $portname] [get_bd_intf_pins $aie/$port]
      }
    }

    # connect AIE stream ports
    set pes [get_bd_cells -filter "NAME =~ *target_ip_*_* && TYPE == ip" -of_objects [get_bd_cells /arch]]
    foreach portname [dict keys $ports] {
      dict with ports $portname {
        set matches [get_bd_intf_pins -of_objects $pes -filter "vlnv == xilinx.com:interface:axis_rtl:1.0 && MODE == [expr {$direction=={out}} ? {{Slave}} : {{Master}}] && CONFIG.TDATA_NUM_BYTES == $width"]
        connect_bd_intf_net [lindex $matches 0] [get_bd_intf_pins $aie/$port]
      }
    }

    set aieprj_file [add_files -norecurse $aieprj]
    set_property file_type AIEPRJ $aieprj_file
    set_property SCOPED_TO_REF [current_bd_design] $aieprj_file
    # scope without leading slash!
    set_property SCOPED_TO_CELLS aie/ai_engine_0 $aieprj_file
    set_property USED_IN_IMPLEMENTATION true $aieprj_file

    return $args
  }

  namespace eval versal {
    proc connect_aie_engines {{args {}}} {
      set old_bd_inst [current_bd_instance .]
      current_bd_instance "/memory"

      set aie_clk [create_bd_pin -type "clk" -dir "I" "aie_clk"]
      set axi_aie [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_AIE"]
      set cips [get_bd_cells *cips*]
      set noc [get_bd_cells *noc*]

      # create additional clock and AXI master port to NoC and connect AI Engines to PS PMC master
      set axi_master_num [get_property CONFIG.NUM_MI $noc]
      set axi_master_name [format "M%02s_AXI" $axi_master_num]
      set pmc_connections [get_property CONFIG.CONNECTIONS [get_bd_intf_pins $noc/S05_AXI]]
      set clk_num [get_property CONFIG.NUM_CLKS $noc]
      set_property CONFIG.NUM_MI [expr $axi_master_num+1] $noc
      set_property CONFIG.NUM_CLKS [expr $clk_num+1] $noc
      set_property CONFIG.CATEGORY {aie} [get_bd_intf_pins $noc/$axi_master_name]
      lappend pmc_connections $axi_master_name {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}
      set_property CONFIG.CONNECTIONS $pmc_connections [get_bd_intf_pins $noc/S05_AXI]

      connect_bd_net $aie_clk [get_bd_pins $noc/aclk$clk_num]
      connect_bd_intf_net [get_bd_intf_pins $noc/$axi_master_name] $axi_aie

      current_bd_instance $old_bd_inst
      return $args
    }

    proc aie_addressmap {{args {}}} {
      set args [lappend args "M_AIE" [list 0x20000000000 0x100000000 0 ""]]
      return $args
    }

    proc aie_pdi {{args {}}} {
      global bitstreamname
      set prjdir [get_property DIRECTORY [current_project]]
      # write bitstream (without any dot in the name)
      set bitstreamname_nodot [string map {. _} $bitstreamname]
      write_device_image -force "$prjdir/${bitstreamname_nodot}.pdi"

      # extract AIE binaries
      set bins [list "aie.cdo.reset.bin" "aie.cdo.clock.gating.bin" "aie.cdo.error.handling.bin" "aie.cdo.elfs.bin" "aie.cdo.init.bin" "aie.cdo.enable.bin"]
      set swpath "$prjdir/adf/sw"
      set swo "$prjdir/adf/sw.o"
      foreach fname $bins {
        exec objcopy -O binary --set-section-flags .$fname=alloc -j .$fname $swo $swpath/$fname -I plugin
      }
      # add AIE binaries to PDI
      set bif [open "$prjdir/tapasco_aie.bif" "w"]
      puts $bif "all: { image {"
      puts $bif "{ type=bootimage, file=$prjdir/${bitstreamname_nodot}.pdi }"
      puts $bif "} image { name=aie_image, id=0x1c000000 { type=cdo"
      foreach fname $bins {
        puts $bif "file = ${swpath}/${fname}"
      }
      puts $bif "} } }"
      close $bif

      exec bootgen -arch versal -image $prjdir/tapasco_aie.bif -w -o ${bitstreamname}.pdi
      return $args
    }
  }

  tapasco::register_plugin "platform::versal::connect_aie_engines" "pre-wiring"
  tapasco::register_plugin "platform::versal::aie_addressmap" "post-address-map"
  tapasco::register_plugin "platform::versal::aie_pdi" "post-bitstream"
}
