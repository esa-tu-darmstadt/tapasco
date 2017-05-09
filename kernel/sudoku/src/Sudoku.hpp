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
#ifndef __SUDOKU_H__
#define __SUDOKU_H__
#include <istream>

class Sudoku {
public:
	Sudoku();
	Sudoku(int grid[9][9]);
	Sudoku(int *grid);
	Sudoku(std::istream &stream);
	Sudoku(const Sudoku &other);
	virtual ~Sudoku() {}

	virtual void display(std::ostream &stream) const;
	//bool solve(int row, int col) { return solve(row, col, grid); }
	bool solve(int row, int col, int grid[9][9]);
	int grid[9][9];

private:
	int safe(int row, int col, int n, int grid[9][9]) const;
};

#endif // __SUDOKU_H__
