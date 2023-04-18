
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

namespace eval sim_plugins {

  # remove subsystems memory and intc
  # empty subsystems lead to an error when generating verilog files in vivado for some reason
  proc remove_empty_subsystems {args} {
    remove_ss memory
    remove_ss intc
  }

  # remove subsystem with name {name}
  proc remove_ss {name} {
    delete_bd_objs [get_bd_cells $name]
  }

  proc generate_zip {args} {
    global bitstreamname
    set project_dir [get_property DIRECTORY [current_project]]
    # puts "project dir: $project_dir"
    ipx::package_project \
    -root_dir [get_property DIRECTORY [current_project]] \
    -vendor esa.informatik.tu-darmstadt.de \
    -library sim -taxonomy /UserIP \
    -force -generated_files -import_files
    # puts "packaged project"

    ipx::create_xgui_files [ipx::current_core]
    # puts "created xgui_files"
    ipx::update_checksums [ipx::current_core]
    # puts "updated checksums"
    ipx::check_integrity [ipx::current_core]
    # puts "checked integrity"
    ipx::save_core [ipx::current_core]
    # puts "saved core"
    # update_ip_catalog -rebuild -repo_path $project_dir
    # puts "created xgui_files"
    ipx::check_integrity -quiet -xrt [ipx::current_core]
    # puts "checked integrity quietly"
    ipx::archive_core "$project_dir/../$bitstreamname.zip" [ipx::current_core]
    # puts "archived core"
  }

}

tapasco::register_plugin "platform::sim_plugins::remove_empty_subsystems" "post-platform"
tapasco::register_plugin "platform::sim_plugins::generate_zip" "post-wrapper"
