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

if {[tapasco::is_feature_enabled "XSA-Export"]} {
  # Export TaPaSCo composition to an XSA file, which in turn can be imported to Vitis

  # Skip synthesis if feature is enabled
  set skip_synth 1

  namespace eval versal {
    proc export_xsa {{args {}}} {
      global bitstreamname

      # activate vitis extensible platform project mode
      set_property platform.extensible true [current_project]

      # Vitis requires at least one master port (slave is optional)
      set_property PFM.AXI_PORT {M04_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"}} [get_bd_cells /memory/host_sc]

      # Vitis requires at least one clock, take the design clock with fixed frequency
      set_property PFM.CLOCK {clk_out1 {id "11" is_default "true" proc_sys_reset "/clocks_and_resets/design_rst_gen" status "fixed"}} [get_bd_cells /clocks_and_resets/design_clk_wiz]

      set_property platform.name {TaPaSCo_Platform} [current_project]
      set_property pfm_name {esa.informatik.tu-darmstadt:platform:tapasco:0.0} [get_files -norecurse *.bd]
      set_property platform.board_id {board} [current_project]
      set_property platform.uses_pr {false} [current_project]
      set_property platform.default_output_type "qspi" [current_project]

      generate_target all [get_files -norecurse *.bd]

      # workaround for vitis parser bug, which does not allow double hyphens within comments
      set bitstream_no_double_hyphen [string map {-- -} $bitstreamname]

      write_hw_platform -hw -force -file [pwd]/$bitstream_no_double_hyphen.xsa
    }
  }

  tapasco::register_plugin "platform::versal::export_xsa" "post-wrapper"
}
