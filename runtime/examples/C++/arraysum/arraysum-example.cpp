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
#include <iostream>
#include <tapasco.hpp>

#define SZ 256
#define RUNS 25

typedef int32_t element_type;
constexpr int PE_ID = 10;

static void init_array(std::array<element_type, SZ> &arr) {
  for (size_t i = 0; i < arr.size(); ++i)
    arr[i] = (element_type)i;
}

static int arraysum(std::array<element_type, SZ> &arr) {
  int sum = 0;
  for (size_t i = 0; i < arr.size(); i++) {
    sum += arr[i];
  }
  return sum;
}

int main(int argc, char **argv) {
  // initialize TaPaSCo
  tapasco::Tapasco tapasco;

  uint64_t errs = 0;

  tapasco::PEId peid = 0;

  try {
    peid = tapasco.get_pe_id("esa.cs.tu-darmstadt.de:hls:arraysum:1.0");
  } catch (...) {
    std::cout << "Assuming old bitstream without VLNV info." << std::endl;
    peid = PE_ID;
  }

  std::cout << "Using PEId " << peid << std::endl;

  // check arraysum instance count
  uint64_t instances = tapasco.kernel_pe_count(peid);
  std::cout << "Got " << instances << " arraysum instances.";
  if (!instances) {
    std::cout << "Need at least one arraysum instance to run.";
    exit(1);
  }

  for (int run = 0; run < RUNS; ++run) {
    // Generate array for arraysum output
    std::array<element_type, SZ> input;
    init_array(input);

    int cpu_sum = arraysum(input);

    // Data will be copied back from the device only, no data will be moved to
    // the device
    auto input_buffer_in = tapasco::makeInOnly(tapasco::makeWrappedPointer(
        input.data(), input.size() * sizeof(element_type)));

    int fpga_sum = -1;
    tapasco::RetVal<int> ret_val(&fpga_sum);

    // Launch the job
    // Arraysum takes only one parameter: The location of the array. It will
    // always summarize 256 Int`s.
    auto job = tapasco.launch(peid, ret_val, input_buffer_in);

    // Wait for job completion. Will block execution until the job is done.
    job();

    if (cpu_sum == fpga_sum) {
      std::cout << "RUN " << run << " OK" << std::endl;
    } else {
      std::cerr << "RUN" << run << " FAILED FPGA: " << fpga_sum
                << " CPU: " << cpu_sum << std::endl;
      ++errs;
    }
  }

  if (!errs)
    std::cout << "Arraysum finished without errors." << std::endl;
  else
    std::cerr << "Arraysum finished wit errors." << std::endl;

  return errs;
}
