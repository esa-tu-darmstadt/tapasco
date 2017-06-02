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
# @file   fancontrol.tcl
# @brief  Plugin to add a primitive counter-based PWM to slow down the noisy
#         fan on the ZC706 (use at own risk!).
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval fancontrol {
  proc fancontrol_feature {{args {}}} {
    if {![dict exists [tapasco::get_architecture_features] "FanControl"] || [tapasco::is_platform_feature_enabled "FanControl"]} {
      put "Building primitive PWM module to subdue the noisy ZC706 fan ..."
      set ps [get_bd_cell -hierarchical -filter {VLNV =~ "xilinx.com:ip:processing_system*"}]
      set cnt [tapasco::createBinaryCounter "pwmcounter" 4]
      set sli [tapasco::createSlice "pwmslice" 4 3]
      set pwm [create_bd_port -dir O "pwm"]
      connect_bd_net $pwm [get_bd_pins "pwmslice/Dout"]
      connect_bd_net [get_bd_pins "pwmcounter/Q"] [get_bd_pins "pwmslice/Din"]
      connect_bd_net [get_bd_pin "$ps/FCLK_CLK0"] [get_bd_pin "$cnt/CLK"]
      add_files -fileset constrs_1 -norecurse "$::env(TAPASCO_HOME)/platform/zc706/plugins/fancontrol-zc706.xdc"
    }
    return {}
  }

  proc fancontrol_falsepath {{args {}}} {
    set port [get_ports -filter {NAME =~ *pwm*}]
    puts "Setting false path on $port, timing does not matter."
    set_false_path -to $port
    return {}
  }
}

tapasco::register_plugin "platform::fancontrol::fancontrol_feature" "post-bd"
tapasco::register_plugin "platform::fancontrol::fancontrol_falsepath" "post-synth"
