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
//! @file	arraysum-example-mt-ff.cc
//! @brief	TPC API based example program exercising a hardware threadpool
//!             containing instances of the arraysum kernel.
//!             Multi-threaded FastFlow variant.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <cerrno>
#include <iostream>
#include <vector>
#include <unistd.h>
#include <cassert>
#include <tapasco.h>
#include <ff/farm.hpp>
#include "arraysum.h"
using namespace ff;
using namespace rpr::tapasco;

#define SZ							256
#define RUNS							10000

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;
static int *arr;
int errs = 0;

static void check(int const result)
{
	if (! result) {
		std::cerr << "fatal error: " << strerror(errno) << std::endl;
		exit(errno);
	}
}

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

static int runTest(int const run)
{
	int const golden = arraysum(&arr[run * SZ]);
	printf("Golden output for run %d: %d\n", run, golden);
	// allocate mem on device and copy array part
	tapasco_handle_t h = tapasco_device_alloc(dev, SZ * sizeof(int), 0);
	check(h != 0);
	check_tapasco(tapasco_device_copy_to(dev, &arr[SZ * run], h, SZ * sizeof(int),
			TAPASCO_COPY_BLOCKING));

	// get a job id and set argument to handle
	tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev, 10,
			TAPASCO_ACQUIRE_JOB_ID_BLOCKING);
	printf("run %d: j_id = %d\n", run, j_id);
	check(j_id > 0);
	check_tapasco(tapasco_device_job_set_arg(dev, j_id, 0, sizeof(h), &h));

	// shoot me to the moon!
	check_tapasco(tapasco_device_job_launch(dev, j_id, TAPASCO_JOB_LAUNCH_BLOCKING));

	// get the result
	int32_t r = 0;
	check_tapasco(tapasco_device_job_get_return(dev, j_id, sizeof(r), &r));
	printf("FPGA output for run %d: %d\n", run, r);
	printf("\nRUN %d %s\n", run, r == golden ? "OK" : "NOT OK");
	tapasco_device_release_job_id(dev, j_id);
	return r == golden ? 0 : 1;
}

struct Emitter: ff_node_t<int> {
	int *svc(int *)
	{
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
	int errs = 0;

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
	// check arraysum instance count
	std::cout << "instance count: " << tapasco_device_func_instance_count(dev, 10)
			<< std::endl;
	assert(tapasco_device_func_instance_count(dev, 10));

	// init whole array to subsequent numbers
	arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(arr != NULL);
	init_array(arr, SZ * RUNS);

	// setup ff_farm
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
		std::cout << "SUCCESS" << std::endl;
	else
		std::cerr << "FAILURE" << std::endl;

	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	free(arr);
	return errs;
}
