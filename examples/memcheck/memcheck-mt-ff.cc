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
//! @file	memcheck-mt-ff.cc
//! @brief	Initializes the first TPC device and iterates over a number
//!  		of integer arrays of increasing size, allocating each array
//!  		on the device, copying to and from and then checking the
//!   		results. Basic regression test for platform implementations.
//!		Multi-threaded FastFlow variant.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <iostream>
#include <iomanip>
#include <vector>
#include <unistd.h>
#include <cassert>
#include <tapasco.h>
#include <ff/farm.hpp>
using namespace ff;
using namespace rpr::tapasco;

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;
static long int errs;
static size_t const arr_szs[] = { 1, 2, 8, 10, 16, 1024, 2048, 4096 };

static void check_tapasco(tapasco_res_t const result)
{
	if (result != TAPASCO_SUCCESS) {
		std::cerr << "tapasco fatal error: " << tapasco_strerror(result)
				<< std::endl;
		exit(result);
	}
}

static void init_array(int *arr, size_t sz)
{
	for (size_t i = 0; i < sz; ++i)
		arr[i] = i;
}

static int compare_arrays(long int const s, int const *arr, int const *rarr,
		size_t const sz, unsigned int const base)
{
	int errs = 0;
	for (size_t i = 0; i < sz; ++i) {
		if (rarr[i] != arr[i]) {
			unsigned int const addr = base + i * sizeof(int);
			fprintf(stderr, "%ld: wrong data: arr[%zd] = %d != %d = rarr[%zd]\terror at 0x%08x\n",
					s, i, arr[i], rarr[i], i, addr);
			++errs;
		}
	}
	return errs;
}

static int runTest(int const s)
{
	std::cout << s << ": Checking array size " << arr_szs[s] << " ("
			<< arr_szs[s] * sizeof(int) << " byte) ... " << std::endl;
	// allocate and fill array
	int *arr = (int *)malloc(arr_szs[s] * sizeof(int));
	assert(arr != NULL);
	init_array(arr, arr_szs[s]);
	// allocate array for read data
	int *rarr = (int *)malloc(arr_szs[s] * sizeof(int));
	assert(rarr != NULL);

	// get tapasco handle
	tapasco_handle_t h;
	tapasco_device_alloc(dev, &h, arr_szs[s] * sizeof(int), 0);
	std::cout << s << ": handle = 0x" << std::hex << std::setfill('0')
			<< std::setw(8) << static_cast<uint32_t>(h)
			<< ", size = " << arr_szs[s] * sizeof(int) << " bytes"
			<< std::endl;
	assert(static_cast<int>(h) > 0);

	// copy data to and back
	int merr = 0;
	std::cout << s << ": sizeof(arr) = " << sizeof(arr)
			<< ", sizeof(rarr) = " << sizeof(rarr) << std::endl;
	tapasco_res_t res = tapasco_device_copy_to(dev, arr, h,
			arr_szs[s] * sizeof(int), TAPASCO_COPY_BLOCKING);
	if (res == TAPASCO_SUCCESS) {
		std::cout << s << ": copy-to successful, copying from ..." << std::endl;
		res = tapasco_device_copy_from(dev, h, rarr,
				arr_szs[s] * sizeof(int), TAPASCO_COPY_BLOCKING);
		std::cout << s << ": copy from finished" << std::endl;
		if (res == TAPASCO_SUCCESS) {
			merr += compare_arrays(s, arr, rarr, arr_szs[s],
					static_cast<unsigned int>(h));
		} else {
			std::cerr << s << ": Copy from device failed." << std::endl;
			merr += 1;
		}
	} else {
		std::cerr << s << ": Copy to device failed." << std::endl;
		merr += 1;
	}
	__sync_add_and_fetch(&errs, merr);
	tapasco_device_free(dev, h, 0);

	if (! merr)
		std::cout << s << ": Array size " << arr_szs[s] << " ("
				<< arr_szs[s] * sizeof(int) << ") ok!"
				<< std::endl;
	else
		std::cerr << s << ": FAILURE: array size " << arr_szs[s]
				<< " (" << arr_szs[s] * sizeof(int)
				<< ") %zd byte) not ok." << std::endl;

	free(arr);
	free(rarr);
	return merr;
}

struct Emitter: ff_node_t<int> {
	int *svc(int *)
	{
		static size_t const RUNS = sizeof(arr_szs) / sizeof(*arr_szs);
		for (size_t i = 0; i < RUNS; ++i)
			ff_send_out(new int(i));
		return EOS;
	}
};
struct Worker: ff_node_t<int> {
	int *svc(int *task)
	{
		int &t = *task;
		t = runTest(t);
		return task;
	}
};
struct Collector: ff_node_t<int> {
	int *svc(int *t)
	{
		__sync_fetch_and_add(&errs, *t);
		delete t;
		return GO_ON;
	}
	void svc_end() { std::cout << "Total number of errors: " << errs << std::endl; }
};

int main(int argc, char **argv)
{
	std::cout << "Running memory transfer checks ..." << std::endl;

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));

	// init ff_farm, one worker per configured processor
	std::vector<ff_node *> f;
	for (int i = 0; i < sysconf(_SC_NPROCESSORS_CONF); ++i)
		f.push_back(new Worker);

	Emitter e;
	Collector c;
	ff_farm<> farm(f, &e, &c);

	farm.set_scheduling_ondemand();
	farm.cleanup_workers();
	farm.run_and_wait_end();

	if (! errs)
		std::cout << "SUCCESS!" << std::endl;
	else
		std::cerr << "FAILURE" << std::endl;

	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	return errs ? EXIT_FAILURE : EXIT_SUCCESS;
}
