//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
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

#include "tpc_api.h"

#define SUDOKU_ID			77

using namespace std;
using namespace rpr::tpc;

static tpc_ctx_t *ctx;
static tpc_dev_ctx_t *dev;

static inline void check_tpc(tpc_res_t const result)
{
	if (result != TPC_SUCCESS) {
		cerr << "tpc fatal error: " << tpc_strerror(result) << endl;
		exit(result);
	}
}

static void init_tpc()
{
	check_tpc(tpc_init(&ctx));
	check_tpc(tpc_create_device(ctx, 0, &dev, 0));
}

static void exit_tpc()
{
	tpc_destroy_device(ctx, dev);
	tpc_deinit(ctx);
}

static bool fpga_sudoku(int grid[9][9])
{
	static atomic<unsigned long> errors {0};
	uint32_t ret;
	tpc_res_t r;
	tpc_job_id_t j_id;
	tpc_handle_t h = tpc_device_alloc(dev, 9*9*sizeof(int), 0);
	if (h <= 0) {
		cerr << "could not allocate memory!";
		errors.fetch_add(1);
		return false;
	}

	r = tpc_device_copy_to(dev, grid, h, 9*9*sizeof(int), TPC_COPY_BLOCKING);
	if (r != TPC_SUCCESS) {
		cerr << "could not copy to device: " << tpc_strerror(r) << endl;
		errors.fetch_add(1);
		tpc_device_free(dev, errors);
		return false;
	}

	j_id = tpc_device_acquire_job_id(dev, SUDOKU_ID, TPC_ACQUIRE_JOB_ID_BLOCKING);
	tpc_device_job_set_arg(dev, j_id, 0, sizeof(h), &h);
	r = tpc_device_job_launch(dev, j_id, TPC_JOB_LAUNCH_BLOCKING);
	if (r != TPC_SUCCESS) {
		cerr << "could not launch kernel: " << tpc_strerror(r) << endl;
		errors.fetch_add(1);
		tpc_device_release_job_id(dev, j_id);
		tpc_device_free(dev, errors);
	}
	usleep(1000);
	tpc_device_job_get_return(dev, j_id, sizeof(ret), &ret);

	r = tpc_device_copy_from(dev, h, grid, 9*9*sizeof(int), TPC_COPY_BLOCKING);
	if (r != TPC_SUCCESS) {
		cerr << "could not copy from device: " << tpc_strerror(r) << endl;
		errors.fetch_add(1);
		tpc_device_free(dev, errors);
		return false;
	}

	tpc_device_release_job_id(dev, j_id);
	tpc_device_free(dev, h);
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
		init_tpc();

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
		exit_tpc();
}

