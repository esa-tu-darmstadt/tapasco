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
//! @file	warraw-example-mt.c
//! @brief	TPC API based example program exercising a hardware threadpool
//!             containing instances of the warraw kernel.
//!             Multi-threaded Pthread variant.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <cerrno>
#include <iostream>
#include <vector>
#include <unistd.h>
#include <cassert>
#include <tpc_api.h>
#include <ff/farm.hpp>
#include "warraw.h"
using namespace ff;
using namespace rpr::tpc;

#define SZ							256
#define RUNS							25	

static tpc_ctx_t *ctx;
static tpc_dev_ctx_t *dev;
static int *arr, *golden_arr;
int errs = 0;

static void check(int const result)
{
	if (! result) {
		std::cerr << "fatal error: " << strerror(errno) << std::endl;
		exit(errno);
	}
}

static void check_tpc(tpc_res_t const result)
{
	if (result != TPC_SUCCESS) {
		std::cerr << "tpc fatal error: " << tpc_strerror(result)
				<< std::endl;
		exit(result);
	}
}

static void init_array(int *arr, size_t sz)
{
	for (size_t i = 0; i < sz; ++i)
		arr[i] = -1;
}

static unsigned int check_arrays(int *arr, int *golden_arr, size_t sz)
{
	unsigned int errs = 0;
	for (size_t i = 0; i < sz; ++i) {
		if (arr[i] != golden_arr[i]) {
			fprintf(stderr, "wrong data at %zd: %d, should be %d\n",
					i, arr[i], golden_arr[i]);
			++errs;
		}
	}
	return errs;
}

static int runTest(int const run)
{
	// golden run
	int golden = warraw(&golden_arr[SZ * run]);
	printf("Golden output for run %d: %d\n", run, golden);

	// allocate mem on device and copy array part
	tpc_handle_t h = tpc_device_alloc(dev, SZ * sizeof(int), 0);
	check(h != 0);
	check_tpc(tpc_device_copy_to(dev, &arr[SZ * run], h, SZ * sizeof(int),
			TPC_COPY_BLOCKING));

	// get a job id and set argument to handle
	tpc_job_id_t j_id = tpc_device_acquire_job_id(dev, 12,
			TPC_ACQUIRE_JOB_ID_BLOCKING);
	printf("run %d: j_id = %d\n", run, j_id);
	check(j_id > 0);
	check_tpc(tpc_device_job_set_arg(dev, j_id, 0, sizeof(h), &h));

	// shoot me to the moon!
	check_tpc(tpc_device_job_launch(dev, j_id, TPC_JOB_LAUNCH_BLOCKING));

	// get the result
	int32_t r = 0;
	check_tpc(tpc_device_job_get_return(dev, j_id, sizeof(r), &r));
	check_tpc(tpc_device_copy_from(dev, h, &arr[SZ * run],
			SZ * sizeof(int), TPC_COPY_BLOCKING));
	printf("TPC output for run %d: %d\n", run, r);
	unsigned int errs = check_arrays(&arr[SZ * run],
			&golden_arr[SZ * run], SZ);
	printf("\nRUN %d %s\n", run, r == golden && errs == 0 ?
			"OK" : "NOT OK");
	tpc_device_free(dev, h);
	tpc_device_release_job_id(dev, j_id);
	return errs;
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
	check_tpc(tpc_init(&ctx));
	check_tpc(tpc_create_device(ctx, 0, &dev, 0));
	// check warraw instance count
	std::cout << "instance count: " << tpc_device_func_instance_count(dev, 12)
			<< std::endl;
	assert(tpc_device_func_instance_count(dev, 12));

	// init whole array to subsequent numbers
	arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(arr != NULL);
	init_array(arr, SZ * RUNS);
	
	golden_arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(golden_arr != NULL);
	init_array(golden_arr, SZ * RUNS);

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
	tpc_destroy_device(ctx, dev);
	tpc_deinit(ctx);
	free(arr);
	free(golden_arr);
	return errs;
}
