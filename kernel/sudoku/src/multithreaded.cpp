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
/**
 *  @file	multithreaded.cpp
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <iostream>
#include <cstdlib>
#include <cerrno>
#include <cstring>
#include <unistd.h>
#include <fstream>
#include <vector>
#include <future>
#include "Timer.hpp"
#include "Sudoku.hpp"
#include "Sudoku_HLS.hpp"

#include "tapasco.h"

#define SUDOKU_ID			77

using namespace std;
using namespace rpr::tapasco;

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;

static inline void check_tapasco(tapasco_res_t const result)
{
	if (result != TAPASCO_SUCCESS) {
		cerr << "tapasco fatal error: " << tapasco_strerror(result) << endl;
		exit(result);
	}
}

static void init_tapasco()
{
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
}

static void exit_tapasco()
{
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
}

static bool fpga_sudoku(int grid[9][9])
{
	static atomic<unsigned long> errors {0};
	uint32_t ret;
	tapasco_res_t r;
	tapasco_job_id_t j_id;
	tapasco_handle_t h = tapasco_device_alloc(dev, 9*9*sizeof(int), 0);
	if (h <= 0) {
		cerr << "could not allocate memory!";
		errors.fetch_add(1);
		return false;
	}

	r = tapasco_device_copy_to(dev, grid, h, 9*9*sizeof(int), TAPASCO_COPY_BLOCKING);
	if (r != TAPASCO_SUCCESS) {
		cerr << "could not copy to device: " << tapasco_strerror(r) << endl;
		errors.fetch_add(1);
		tapasco_device_free(dev, errors);
		return false;
	}

	j_id = tapasco_device_acquire_job_id(dev, SUDOKU_ID, TAPASCO_ACQUIRE_JOB_ID_BLOCKING);
	tapasco_device_job_set_arg(dev, j_id, 0, sizeof(h), &h);
	r = tapasco_device_job_launch(dev, j_id, TAPASCO_JOB_LAUNCH_BLOCKING);
	if (r != TAPASCO_SUCCESS) {
		cerr << "could not launch kernel: " << tapasco_strerror(r) << endl;
		errors.fetch_add(1);
		tapasco_device_release_job_id(dev, j_id);
		tapasco_device_free(dev, errors);
	}
	usleep(1000);
	tapasco_device_job_get_return(dev, j_id, sizeof(ret), &ret);

	r = tapasco_device_copy_from(dev, h, grid, 9*9*sizeof(int), TAPASCO_COPY_BLOCKING);
	if (r != TAPASCO_SUCCESS) {
		cerr << "could not copy from device: " << tapasco_strerror(r) << endl;
		errors.fetch_add(1);
		tapasco_device_free(dev, errors);
		return false;
	}

	tapasco_device_release_job_id(dev, j_id);
	tapasco_device_free(dev, h);
	return ret != 0;
}

int main(int argc, char *argv[])
{
	long thrdcnt {sysconf(_SC_NPROCESSORS_CONF)};
	int c {2};
	int const mode {argc > 2 && argv[1][0] == 'f'};

	if (argc < 3) {
		cerr << "Usage: sudoku_mt <cpu|fgpa> [<number of threads>] <filename1> <filename2> ..." << endl;
		exit(EXIT_FAILURE);
	}

	if (argc > 3) {
		unsigned long t = strtoul(argv[c++], NULL, 0);
		if (t)
			thrdcnt = t;
	}

	cout << "Solving with " << thrdcnt << " threads ..." << endl;

	if (mode)
		init_tapasco();

	auto start = chrono::steady_clock::now();
	for (; c < argc; ++c) {
		ifstream f(argv[c]);
		vector<int *> puzzles;
		vector<future<bool> > futures;
		int i;
		Sudoku s;

		while (f.good() && ! f.eof()) {
			Sudoku s(f);
			int i, j;
			s.display(cout);
			int *grid = new int[9*9]();
			for (i = 0; i < 9; ++i)
				for (j = 0; j < 9; ++j)
					grid[i * 9 + j] = s.grid[i][j];
			puzzles.push_back(grid);
			cout << endl;
		}

		cout << "Number of puzzles: " << puzzles.size() << endl;

		for (int *p : puzzles) {
			int (*grid)[9] = (int (*)[9])p;
			if (mode) {
				futures.push_back(async(launch::async, fpga_sudoku, grid));
			} else {
				futures.push_back(async(launch::async, sudoku_solve, grid));
			}
		}

		i = 0;
		for (auto &e : futures) {
			bool const solved = e.get();
			cout << "Puzzle # " << i << ": " << (solved ? "solved" : "not solved") << endl;
			/*if (solved)*/ {
				cout << "Solution: " << endl;
				volatile int *p = puzzles.at(i);
				int g[9][9];
				for (int i = 0; i < 9; ++i)
					for (int j = 0; j < 9; ++j)
						g[i][j] = *p, ++p;
				Sudoku s((int *)g);
				s.display(cout);
			}
			++i;
		}

		for (int *p : puzzles)
			delete[] p;
	}
	auto stop = chrono::steady_clock::now();
	cout << "Wall clock time for solving: " << chrono::duration<double, milli>(stop - start).count() << " ms." << endl;

	if (mode)
		exit_tapasco();
}

