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
#include <iostream>
#include <fstream>
#include <cstdlib>
#include "Timer.hpp"
#include "Sudoku.hpp"
#include "Sudoku_HLS.hpp"

#ifdef __C_BENCH__
#include <fstream>
#include <iomanip>
#endif

#ifndef NORMAL_MODE
#include <string.h>
#endif

using namespace std;

int main(int argc, char *argv[])
{	
	Timer timer;
	unsigned long long usecs = 0;
	long pn = 1, sp = 0;
	int ret = 0;

	#ifdef __C_BENCH__
	std::ofstream preload, check;
	preload.open("preload_ddr.txt", std::ios::trunc);
	check.open("check_ddr.txt", std::ios::trunc);
	#endif

	#ifdef NORMAL_MODE
	if (argc != 2) {
		cerr << "Expected file argument with puzzle descriptions" << endl;
		exit(1);
	}
	ifstream f(argv[1]);
	#else
	ifstream f("hard_sudoku.txt");
	#endif

	if (! f.is_open()) {
		cerr << "Could not open '" << argv[1] << endl;
		exit(1);
	}

	do {
		Sudoku s(f);
		cout << "Puzzle #" << pn++ << endl;
		s.display(cout);
		#ifdef __C_BENCH__
		for (int i = 0; i < 9*9; ++i) {
			preload << std::setfill('0') << std::setw(8) << s.grid[i / 9][i % 9] << std::endl;
		}
		#endif
		timer.start();
		bool solved = sudoku_solve(s.grid);
		timer.stop();
		usecs += timer.micro_secs();

		if (solved) {
			cout << "Solution #" << (pn-1) << endl;
			s.display(cout);
			sp++;
			#ifdef __C_BENCH__
			for (int i = 0; i < 9*9; ++i) {
				check << std::setfill('0') << std::setw(8) << s.grid[i / 9][i % 9] << std::endl;
			}
			#endif
		}

		#ifndef NORMAL_MODE
		ifstream sol("hard_sudoku_solution.txt");
		Sudoku solution(sol);
		ret = memcmp(solution.grid, s.grid, 81 * sizeof(int));
		#endif
	} while (! f.eof());

	cout << "Solved " << sp << " of " << (pn-1) << " puzzles, "
			<< "took average time of " << (usecs / (pn-1)) 
			<< " us per puzzle (total time: " 
			<< (usecs / 1000000L) << " s)." << endl;

	f.close();

	#ifdef __C_BENCH__
	preload.close();
	check.close();
	#endif

	return ret;
}
