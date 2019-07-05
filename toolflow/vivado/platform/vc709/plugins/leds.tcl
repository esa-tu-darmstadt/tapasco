#
# Copyright (C) 2019 Carsten Heinz, TU Darmstadt
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

namespace eval leds {
  proc get_led_port_name {} {
	return "LED_Port"
  }

  proc get_led_count {} {
	return 8
  }

  proc get_default_pins {} {
	return [list \
      "/host/axi_pcie3_0/user_link_up" \
      "/memory/mig/init_calib_complete" \
      "/clocks_and_resets/host_peripheral_aresetn" \
      "/clocks_and_resets/design_peripheral_aresetn" \
    ]
  }

  proc load_constraints {} {
    read_xdc -unmanaged "$::env(TAPASCO_HOME_TCL)/platform/vc709/plugins/leds.xdc"
  }
}
