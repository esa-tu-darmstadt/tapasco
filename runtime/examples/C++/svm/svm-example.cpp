/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <array>
#include <vector>
#include <iostream>
#include <tapasco.hpp>
#include <algorithm>

#define SZ 256
#define RUNS 25

typedef int32_t element_type;

static void init_array(element_type *arr) {
	for (size_t i = 0; i < SZ; ++i)
		arr[i] = (element_type)i;
}

static uint64_t check_arrayinit(element_type *arr)
{
	unsigned int errs = 0;
	for (size_t i = 0; i < SZ; ++i) {
		if (arr[i] != (element_type) i) {
			std::cerr << "ERROR: Value at " << i << " is " << arr[i] << std::endl;
			++errs;
		}
	}
	return errs;
}

static int check_arraysum(element_type *arr, int result)
{
	int sum = 0;
	for (size_t i = 0; i < SZ; ++i) {
		sum += arr[i];
	}
	return (sum != result);
}

static int check_arrayupdate(element_type *arr)
{
	int errs = 0;
	for (size_t i = 0; i < SZ; i++) {
		if (arr[i] != ((element_type) i) + 42) {
			std::cerr << "ERROR: Value at " << i << " is " << arr[i] << std::endl;
			++errs;
		}
	}
	return errs;
}

static int check_pipeline(int res)
{
	// create reference
	int ref = 0;
	for (size_t i = 0; i < SZ; ++i) {
		ref += i + 42;
	}
	return (ref != res);
}

int run_arrayinit(tapasco::Tapasco *tapasco, tapasco::PEId arrayinit_id)
{
	uint64_t errs = 0;
	std::cout << "Run arrayinit using on-demand page migrations (ODPMs) ..." << std::endl;
	for (int run = 0; run < RUNS; ++run) {
		// Generate array for arrayinit output
		auto *result = new element_type[SZ];

		// Launch the job
		// Arrayinit takes only one parameter: The location of the array. It will
		// always initialize 256 Int`s.
		//
		// When using ODPMs we just pass the array base address
		// -> the migration will be triggered automatically by device and CPU page faults
		// -> wrapping the pointer in the VirtualAddress argument type provides a
		//    check whether the loaded bitstream actually supports SVM
		auto job = tapasco->launch(arrayinit_id, tapasco::makeVirtualAddress(result));

		// Wait for job completion. Will block execution until the job is done.
		job();

		uint64_t iter_errs = check_arrayinit(result);
		errs += iter_errs;
		std::cout << "RUN " << run << " " << (iter_errs == 0 ? "OK" : "NOT OK")
			  << std::endl;
		delete[] result;
	}

	std::cout << "Run arrayinit using user-managed page migrations (UMPMs) ..." << std::endl;
	for (int run = 0; run < RUNS; ++run) {
		// Generate array for arrayinit output
		auto *result = new element_type[SZ];

		// Launch the job
		// Arrayinit takes only one parameter: The location of the array. It will
		// always initialize 256 Int`s.
		//
		// To use UMPMs we wrap the pointer as when using TaPaSCo without SVM
		// -> Note that we do NOT use makeOutOnly<T> since the array is allocated in
		//    host memory and needs to be migrated to device memory as well
		auto job = tapasco->launch(arrayinit_id, tapasco::makeWrappedPointer(
			result, SZ * sizeof(element_type)));

		// Wait for job completion. Will block execution until the job is done.
		job();

		int iter_errs = check_arrayinit(result);
		errs += iter_errs;
		std::cout << "RUN " << run << " " << (iter_errs == 0 ? "OK" : "NOT OK")
			  << std::endl;
		delete[] result;
	}

	return (errs != 0);
}

int run_arraysum(tapasco::Tapasco *tapasco, tapasco::PEId arraysum_id)
{
	int errs = 0;
	std::cout << "Run arraysum using on-demand page migrations (ODPMs) ..." << std::endl;
	for (int run = 0; run < RUNS; ++run) {
		// Generate array for arraysum
		auto *arr = new element_type[SZ];
		init_array(arr);

		// variable for return value
		int fpga_sum = -1;
		tapasco::RetVal<int> ret_val(&fpga_sum);

		// Launch the job
		// Arraysum takes only one parameter: The location of the array. It will
		// always summarize 256 Int`s.
		//
		// When using ODPMs we just pass the array base address
		// -> the migration will be triggered automatically by device page faults
		// -> wrapping the pointer in the VirtualAddress argument type provides a
		//    check whether the loaded bitstream actually supports SVM
		auto job = tapasco->launch(arraysum_id, ret_val, tapasco::makeVirtualAddress(arr));

		// Wait for job completion. Will block execution until the job is done.
		job();

		if (check_arraysum(arr, fpga_sum)) {
			++errs;
			std::cerr << "RUN" << run << " NOT OK" << std::endl;

		} else {
			std::cout << "RUN " << run << " OK" << std::endl;
		}
		delete[] arr;
	}


	std::cout << "Run arraysum using user-managed page migrations (UMPMs) ..." <<
		  std::endl;
	for (int run = 0; run < RUNS; ++run) {
		// Generate array for arraysum
		auto *arr = new element_type[SZ];
		init_array(arr);

		// variable for return value
		int fpga_sum = -1;
		tapasco::RetVal<int> ret_val(&fpga_sum);

		// Launch the job
		// Arrayinit takes only one parameter: The location of the array. It will
		// always initialize 256 Int`s.
		//
		// To use UMPMs we wrap the pointer as when using TaPaSCo without SVM
		// -> Note that we use makeInOnly<T> since the array can be freed
		//    directly in device memory and does not have to be migrated back
		auto job = tapasco->launch(arraysum_id, ret_val, tapasco::makeInOnly(
			tapasco::makeWrappedPointer(arr, SZ * sizeof(element_type))));

		// Wait for job completion. Will block execution until the job is done.
		job();

		if (check_arraysum(arr, fpga_sum)) {
			++errs;
			std::cerr << "RUN" << run << " NOT OK" << std::endl;

		} else {
			std::cout << "RUN " << run << " OK" << std::endl;
		}
		delete[] arr;
	}

	return errs;
}

int run_arrayupdate(tapasco::Tapasco *tapasco, tapasco::PEId arrayupdate_id)
{
	int errs = 0;
	std::cout << "Run arrayupdate using on-demand page migrations (ODPMs) ..." << std::endl;
	for (int run = 0; run < RUNS; ++run) {
		// Generate array for arrayupdate
		auto *arr = new element_type[SZ];
		init_array(arr);

		// Launch the job
		// Arrayupdate takes only one parameter: The location of the array. It will
		// always summarize 256 Int`s.
		//
		// When using ODPMs we just pass the array base address
		// -> the migration will be triggered automatically by device and CPU page faults
		// -> wrapping the pointer in the VirtualAddress argument type provides a
		//    check whether the loaded bitstream actually supports SVM
		auto job = tapasco->launch(arrayupdate_id, tapasco::makeVirtualAddress(arr));

		// Wait for job completion. Will block execution until the job is done.
		job();

		int iter_errs = check_arrayupdate(arr);
		errs += iter_errs;
		std::cout << "RUN " << run << " " << (iter_errs == 0 ? "OK" : "NOT OK")
			  << std::endl;
		delete[] arr;
	}

	std::cout << "Run arrayupdate using user-managed page migrations (UMPMs) ..." <<
		  std::endl;
	//for (int run = 0; run < RUNS; ++run) {
	for (int run = 0; run < RUNS; ++run) {
		// Generate array for arraysum
		auto *arr = new element_type[SZ];
		init_array(arr);

		// Launch the job
		// Arrayupdate takes only one parameter: The location of the array. It will
		// always initialize 256 Int`s.
		//
		// To use UMPMs we wrap the pointer as when using TaPaSCo without SVM
		// -> Note that we use only a wrapped pointer since the array must be
		//    migrated to and also back from device memory
		auto job = tapasco->launch(arrayupdate_id, tapasco::makeWrappedPointer(
			arr, SZ * sizeof(element_type)));

		// Wait for job completion. Will block execution until the job is done.
		job();

		int iter_errs = check_arrayupdate(arr);
		errs += iter_errs;
		std::cout << "RUN " << run << " " << (iter_errs == 0 ? "OK" : "NOT OK")
			  << std::endl;
		delete[] arr;
	}

	return 0;
}

/*
 * In this example we create a small pipeline:
 *   1. arrayinit initializes the array
 *   2. arrayupdate adds 42 to every entry
 *   3. arraysum sums up all values
 *
 *   The three PEs may be distributed across different FPGAs
 */
int run_pipeline(tapasco::Tapasco *arrayinit_dev, tapasco::PEId arrayinit_id, tapasco::Tapasco *arrayupdate_dev,
		 tapasco::PEId arrayupdate_id, tapasco::Tapasco *arraysum_dev, tapasco::PEId arraysum_id)
{
	// allocate array
	auto *arr = new element_type[SZ];
	auto arr_wrapped = tapasco::makeInOnly(tapasco::makeWrappedPointer(arr, SZ * sizeof(element_type)));
	auto arr_addr = tapasco::makeVirtualAddress(arr);
	int fpga_sum = -1;
	tapasco::RetVal<int> ret_val(&fpga_sum);

	// Launch arrayinit
	// Here we use the wrapped pointer to use a UMPM to device memory for more efficiency
	auto init_job = arrayinit_dev->launch(arrayinit_id, arr_wrapped);
	init_job();

	// Launch arrayupdate and arraysum
	// We now pass the array base address to the PEs
	// When running pipeline on one FPGA only, the data is already
	// present in device memory (no further migrations required)
	// In a distributed setting a direct device-to-device migration is initiated by a page fault
	auto update_job = arrayupdate_dev->launch(arrayupdate_id, arr_addr);
	update_job();
	auto sum_job = arraysum_dev->launch(arraysum_id, ret_val, arr_addr);
	sum_job();
	return check_pipeline(fpga_sum);
}

bool vector_all_zero(std::vector<int> v) {
	return std::all_of(v.begin(), v.end(), [](int i) {return i == 0;});
}

int main(int argc, char **argv)
{
	// Use C API to get number of TaPaSCo devices
	tapasco::TLKM *tlkm = tapasco::tapasco_tlkm_new();
	int num_devices = tapasco::tapasco_tlkm_device_len(tlkm);
	std::cout << "Found " << num_devices << " TaPaSCo devices." << std::endl;

	// initialize TaPaSCo devices
	std::vector<tapasco::Tapasco *> devices;
	for (int i = 0; i < num_devices; ++i) {
		// pass access types and device ID to constructor (not required if only one device is used)
		devices.push_back(new tapasco::Tapasco(tapasco::tlkm_access::TlkmAccessExclusive, i));
	}

	// find PE IDs and count available PEs on all devices
	tapasco::PEId arrayinit_id, arrayupdate_id, arraysum_id;
	std::vector<int> arrayinit_pe_count, arrayupdate_pe_count, arraysum_pe_count;
	for (auto d : devices) {
		try {
			auto id = d->get_pe_id("esa.cs.tu-darmstadt.de:hls:arrayinit:1.0");
			arrayinit_pe_count.push_back(d->kernel_pe_count(id));
			arrayinit_id = id;
		} catch (...) {
			arrayinit_pe_count.push_back(0);
		}

		try {
			auto id = d->get_pe_id("esa.cs.tu-darmstadt.de:hls:arrayupdate:1.0");
			arrayupdate_pe_count.push_back(d->kernel_pe_count(id));
			arrayupdate_id = id;
		} catch (...) {
			arrayupdate_pe_count.push_back(0);
		}

		try {
			auto id = d->get_pe_id("esa.cs.tu-darmstadt.de:hls:arraysum:1.0");
			arraysum_pe_count.push_back(d->kernel_pe_count(id));
			arraysum_id = id;
		} catch (...) {
			arraysum_pe_count.push_back(0);
		}
	}

	// No PE found to run any tests
	if (vector_all_zero(arrayinit_pe_count) && vector_all_zero(arrayupdate_pe_count) &&
	    vector_all_zero(arraysum_pe_count)) {
		std::cout << "ERROR: Need at least one arrayinit, arraysum or arrayupdate instance to run." << std::endl;
		exit(1);
	}

	// Run tests on all devices if PEs are available
	for (int i = 0; i < num_devices; ++i) {
		if (arrayinit_pe_count[i]) {
			std::cout << "Run arrayinit example..." << std::endl;
			if (run_arrayinit(devices[i], arrayinit_id)) {
				std::cout << "An error occurred while running the arrayinit example, exiting..."
					  << std::endl;
				exit(1);
			} else {
				std::cout << "Completed arrayinit example successfully!" << std::endl;
			}
		}

		if (arrayupdate_pe_count[i]) {
			std::cout << "Run arrayupdate example..." << std::endl;
			if (run_arrayupdate(devices[i], arrayupdate_id)) {
				std::cout << "An error occurred while running the arrayupdate example, exiting..."
					  << std::endl;
				exit(1);
			} else {
				std::cout << "Completed the arrayupdate example successfully!" << std::endl;
			}
		}

		if (arraysum_pe_count[i]) {
			std::cout << "Run arraysum example..." << std::endl;
			if (run_arraysum(devices[i], arraysum_id)) {
				std::cout << "An error occurred while running the arraysum example, exiting..."
					  << std::endl;
				exit(1);
			} else {
				std::cout << "Completed the arraysum example successfully!" << std::endl;
			}
		}
	}

	// try to run pipeline example distributed over multiple devices (nothing sophisticated ^^)
	int arrayinit_device_idx = -1, arrayupdate_device_idx = -1, arraysum_device_idx = -1;
	for (int i = 0; i < num_devices; ++i) {
		if (arrayinit_pe_count[i]) {
			arrayinit_device_idx = i;
			break;
		}
	}
	for (int i = 0; i < num_devices; ++i) {
		if (arrayupdate_pe_count[i]) {
			arrayupdate_device_idx = i;
			if (arrayupdate_device_idx != arrayinit_device_idx)
				break;
		}
	}
	for (int i = 0; i < num_devices; ++i) {
		if (arraysum_pe_count[i]) {
			arraysum_device_idx = i;
			if (arraysum_device_idx != arrayupdate_device_idx)
				break;
		}
	}

	if (arrayinit_device_idx != -1 && arrayupdate_device_idx != -1 && arraysum_device_idx != -1) {
		std::cout << "Run pipeline example..." << std::endl;
		if (run_pipeline(devices[arrayinit_device_idx], arrayinit_id, devices[arrayupdate_device_idx],
				 arrayupdate_id, devices[arraysum_device_idx], arraysum_id)) {
			std::cout << "An error occurred while running the pipeline example, exiting..." << std::endl;
			exit(1);
		} else {
			std::cout << "Completed the pipeline example successfully!" << std::endl;
		}
	}
	return 0;
}
