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
#include "Sudoku.hpp"
#include <cstring>
#include <cctype>
#include <iostream>
#include <assert.h>
#include <cstdio>
#include "LookupTable.h"

using namespace std;

Sudoku::Sudoku()
{
	for (int y = 0; y < 9; ++y)
		for (int x = 0; x < 9; ++x)
			grid[y][x] = 0;
}

/*Sudoku::Sudoku(int g[9][9])
{
	memcpy(this->grid, g, sizeof(*g) * 81);
}*/

Sudoku::Sudoku(int *g)
{
	memcpy(this->grid, g, sizeof(*g) * 81);
}

Sudoku::Sudoku(istream &str)
{
	memset(grid, 0, sizeof(grid));
	for (long y = 0; y < 9; ++y) {
		for (long x = 0; x < 9; ++x) {
			char c = '0';
			do {
				str.get(c);
				if (c >= '0' && c <= '9')
					grid[y][x] = c - '0';
				else
					grid[y][x] = 0;
			} while (isspace(c) && ! str.eof());
		}
	}
	// consume trailing whitespace
	char c = '0';
	while (isspace(str.peek()))
		str.get(c);
}

Sudoku::Sudoku(const Sudoku &other)
{
	memcpy(grid, other.grid, sizeof(grid));
}

void Sudoku::display(ostream &str) const
{ 
	for (long y = 0; y < 9; ++y) {
		if (y > 0 && y % 3 == 0) str << "---+---+---" << endl;
		for (long x = 0; x < 9; ++x) {
			if (x > 0 && x % 3 == 0) str << "|";
			str << grid[y][x];
		}
		str << endl;
	}
	str << endl;
}

int Sudoku::safe(int row, int col, int n, int grid[9][9]) const
{
	int const r_l = row == 0 || row == 3 || row == 6;
	int const r_m = row == 1 || row == 4 || row == 7;
	int const c_l = col == 0 || col == 3 || col == 6;
	int const c_m = col == 1 || col == 4 || col == 7;

	return
		grid[row][col] == n || !(
				grid[0][col] == n ||
				grid[1][col] == n ||
				grid[2][col] == n ||
				grid[3][col] == n ||
				grid[4][col] == n ||
				grid[5][col] == n ||
				grid[6][col] == n ||
				grid[7][col] == n ||
				grid[8][col] == n ||
				grid[row][0] == n ||
				grid[row][1] == n ||
				grid[row][2] == n ||
				grid[row][3] == n ||
				grid[row][4] == n ||
				grid[row][5] == n ||
				grid[row][6] == n ||
				grid[row][7] == n ||
				grid[row][8] == n ||
				grid[row + (r_l ? +1 : (r_m ? -1 : -2))][col + (c_l ? +1 : (c_m ? -1 : -2))] == n ||
				grid[row + (r_l ? +2 : (r_m ? +1 : -1))][col + (c_l ? +1 : (c_m ? -1 : -2))] == n ||
				grid[row + (r_l ? +1 : (r_m ? -1 : -2))][col + (c_l ? +2 : (c_m ? +1 : -1))] == n ||
				grid[row + (r_l ? +2 : (r_m ? +1 : -1))][col + (c_l ? +2 : (c_m ? +1 : -1))] == n);

}

#define ENCODE(row, col, n)	(((row) << 24) | (((col) & 0xFF) <<16) | ((n) & 0xFF))
#define DECODE(v, row, col, n)	do { \
	row = ((v) >> 24); \
	col = ((v) >> 16) & 0xFF; \
	n = (v) & 0xFF; \
} while (0)

bool Sudoku::solve(int row, int col, int grid[9][9])
{
	int n = 1;
	unsigned sptr = 0;
	unsigned stack[81];

	while (row < 9) {
		if (grid[row][col]) {
			if (col == 8)
				row++, col = 0;
			else
				col++;
		} else {
			while (n <= 9 && !safe(row, col, n, grid))
				++n;
			if (n <= 9) {
				stack[sptr++] = ENCODE(row, col, n);
				grid[row][col] = n;
				n = 1;
				if (col == 8)
					row++, col = 0;
				else
					col++;
			} else {
				if(sptr == 0) return false;
				unsigned v = stack[--sptr];
				DECODE(v, row, col, n);
				grid[row][col] = 0;
				++n;
			}
		}
	}
	return true;
}

