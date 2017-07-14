//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
#include "Sudoku_HLS.hpp"
#include "Sudoku.hpp"

#include <iostream>

bool sudoku_solve(int grid[9][9])
{

	static Sudoku s;
	int sgrid[9][9];
	int i, j;
	for (i = 0; i < 9; ++i)
#pragma HLS LOOP_UNROLL skip_exit_check
		for (j = 0; j < 9; ++j)
#pragma HLS LOOP_UNROLL skip_exit_check
			sgrid[i][j] = grid[i][j];
	int res = s.solve(0, 0, sgrid);
	for (i = 0; i < 9; ++i)
#pragma HLS LOOP_UNROLL skip_exit_check
		for (j = 0; j < 9; ++j)
#pragma HLS LOOP_UNROLL skip_exit_check
			grid[i][j] = sgrid[i][j];
	return res;
}
