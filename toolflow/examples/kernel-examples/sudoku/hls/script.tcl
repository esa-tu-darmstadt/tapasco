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
open_project SudokuSolver
set_top "sudoku_solve"
add_files ../src/Sudoku_HLS.cpp
add_files ../src/Sudoku.cpp
add_files -tb ../src/main.cpp
add_files -tb ../puzzles/hardest_puzzles.txt
add_files -tb ../puzzles/hard_puzzles.txt
add_files -tb ../puzzles/easy_puzzles.txt
open_solution "ap_bus"
set_part {xc7z045ffg900-1}
create_clock -period 4 -name default
source "./directives.tcl"
csim_design -argv {hardest_puzzles.txt}
csynth_design
#cosim_design -trace_level none -argv {hardest_puzzles.txt} -rtl verilog -tool modelsim
export_design -evaluate verilog -format ip_catalog -description "Vivado HLS ap_bus variant" -vendor "esa.cs.tu-darmstadt.de" -library "HLS" -version "1.0" -display_name "Sudoku"
#export_design -format ip_catalog -description "Vivado HLS ap_bus variant" -vendor "esa.cs.tu-darmstadt.de" -library "HLS" -version "1.0" -display_name "Sudoku"
close_solution
