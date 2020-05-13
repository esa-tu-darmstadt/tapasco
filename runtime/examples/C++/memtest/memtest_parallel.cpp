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
#include <climits>
#include <iomanip>
#include <iostream>
#include <tapasco.hpp>
#include <vector>

using namespace tapasco;

// runtime for random access benchmark in milliseconds
constexpr int random_time_ms = 1000;
// iterations for batch access benchmark
constexpr int batch_iterations = 1000;
// iterations for latency benchmark
constexpr int latency_iterations = 100000;
// whether to initialize the memory before the benchmarks (required for ECC
// memory) should later be determined automatically when the status core
// provides this information
constexpr bool ecc_memory = true;

constexpr int PE_ID = 321;
// column width used for printing the results in a table
constexpr int col_width = 20;
constexpr char space = ' ';

// determines smallest transfer size for batch; transfer size is
// 2^batch_min_length Bytes
constexpr int batch_min_length = 10;
// determines biggest transfer size for batch; transfer size is
// 2^batch_max_length Bytes
constexpr int batch_max_length = 25;

// number of different request sizes for random benchmark
constexpr int random_byte_length_c = 10;
// request sizes for random benchmark in bytes
constexpr int random_byte_length[random_byte_length_c] = {
    8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096};
constexpr int random_read_seed = 1234;
constexpr int random_write_seed = 5678;

double calcSpeed(unsigned long amount, unsigned long cycles, float clock) {
  // calculate transfer speed in GiB/s for given transfer amount (in bytes) and
  // time in cycles; clock speed is given in MHz
  return (amount / (cycles / (clock * 1000000.0))) / (1024 * 1024 * 1024);
}

void executeRandomBenchmark(tapasco::Tapasco &tapasco, int op,
                            unsigned long cycles, int byte_length,
                            float designclk, int instances) {
  char text[20];
  // allocate vectors for jobs and return values
  std::vector<tapasco::job_future> jobs;
  std::vector<tapasco::RetVal<unsigned long>> retvals;
  retvals.reserve(instances);
  unsigned long rets[instances];

  // start one job for each instance of the PE found
  for (int instance = 0; instance < instances; instance++) {
    rets[instance] = 0;
    tapasco::RetVal<unsigned long> ret_val(&rets[instance]);
    retvals.push_back(ret_val);
    // first argument is operation: 3 means Random Read, 4 Random Write, 5
    // Random Read/Write second argument is runtime in cycles third argument is
    // request size in bytes (maximum 4096) fourth and fifth arguments are seeds
    // for the read and write address generation respectively
    auto job = tapasco.launch(PE_ID, retvals[instance], 3 + op, cycles,
                              byte_length, random_read_seed, random_write_seed);
    jobs.push_back(job);
  }

  unsigned long acc = 0;
  for (int instance = 0; instance < instances; instance++) {
    // when job is finished use return value (completed requests) to calculate
    // performance
    jobs[instance]();
    acc += *retvals[instance].value;
    double iops = *retvals[instance].value / (cycles / (designclk * 1000000.0));
    snprintf(text, 20, "%.2fMIOPS", iops / 1000000);
    std::cout << std::left << std::setw(col_width) << std::setfill(space)
              << text;
  }

  double iops = acc / (cycles / (designclk * 1000000.0));
  snprintf(text, 20, "%.2fMIOPS", iops / 1000000);
  std::cout << std::left << std::setw(col_width) << std::setfill(space) << text;
}

void benchmarkRandom(tapasco::Tapasco &tapasco, float designclk,
                     unsigned long cycles, int instances) {
  if (ecc_memory) {
    std::cout << "Initializing memory (required for ECC memory)" << std::endl;
    // To initialize memoryn write with biggest request size for double
    // benchmark time one time with read-address-seed second time with
    // write-address-seed this ensures all addresses which will later be
    // accessed were already initialized
    auto job = tapasco.launch(PE_ID, 4, 2 * cycles, 4096, random_read_seed,
                              random_read_seed);
    job();
    job = tapasco.launch(PE_ID, 4, 2 * cycles, 4096, random_write_seed,
                         random_write_seed);
    job();
  }
  char text[20];
  std::cout << std::endl << std::endl;
  std::cout << "Random Access Read/Write (" << cycles << " Cycles)" << std::endl
            << std::endl;

  // print table header
  std::cout << std::left << std::setw(col_width) << std::setfill(space)
            << "Size";
  for (int instance = 0; instance < instances; instance++) {
    snprintf(text, 20, "Instance %i", instance);
    std::cout << std::left << std::setw(col_width) << std::setfill(space)
              << text;
  }
  std::cout << std::left << std::setw(col_width) << std::setfill(space)
            << "Total";
  std::cout << std::endl;

  // execute random benchmark for different request sizes
  for (int count = 0; count < random_byte_length_c; count++) {
    snprintf(text, 20, "%iB", random_byte_length[count]);
    std::cout << std::left << std::setw(col_width) << std::setfill(space)
              << text;
    // execute Random Read/Write
    executeRandomBenchmark(tapasco, 2, cycles, random_byte_length[count],
                           designclk, instances);
    std::cout << std::endl;
  }
}

void executeBatchBenchmark(tapasco::Tapasco &tapasco, float designclk, int op,
                           size_t size, int instances) {
  // calculate transfer size (2^size)
  size_t len = 1 << size;

  // init one "global" accumulator and one accumulator for each PE
  // will be used to accumulate the return values of the jobs over all
  // iterations
  unsigned long acc = 0;
  unsigned long accs[instances];
  for (int instance = 0; instance < instances; instance++)
    accs[instance] = 0;

  // execute given number of iterations
  for (int i = 0; i < batch_iterations; i++) {
    // allocate vectors for jobs and return values
    std::vector<tapasco::job_future> jobs;
    std::vector<tapasco::RetVal<unsigned long>> retvals;
    retvals.reserve(instances);
    unsigned long rets[instances];
    // start one job for each instance of the PE found
    for (int instance = 0; instance < instances; instance++) {
      rets[instance] = 0;
      tapasco::RetVal<unsigned long> ret_val(&rets[instance]);
      retvals.push_back(ret_val);
      // first argument is operation: 0 for Batch Read, 1 for Batch Write, 2 for
      // Batch Read/Write second argument is unused third argument is transfer
      // size
      auto job = tapasco.launch(PE_ID, retvals[instance], op, 0, len);
      jobs.push_back(job);
    }
    for (int instance = 0; instance < instances; instance++) {
      // when job finished add return value (transfer time in cycles) to
      // accumulators
      jobs[instance]();
      accs[instance] += *retvals[instance].value;
      acc += *retvals[instance].value;
    }
  }

  // Use accumulators to compute individual and total performance values
  unsigned long total_data = len * batch_iterations;
  if (op == 2)
    total_data *= 2;
  char text[20];
  for (int instance = 0; instance < instances; instance++) {
    snprintf(text, 20, "%#.3fGiB/s",
             calcSpeed(total_data, accs[instance], designclk));
    std::cout << std::left << std::setw(col_width) << std::setfill(space)
              << text;
  }
  snprintf(text, 20, "%#.3fGiB/s",
           calcSpeed(total_data * instances, acc / instances, designclk));
  std::cout << std::left << std::setw(col_width) << std::setfill(space) << text;
}

void benchmarkBatch(tapasco::Tapasco &tapasco, float designclk, int instances) {
  char text[20];
  std::cout << std::endl << std::endl;

  std::cout << "Batch Access Read/Write (" << batch_iterations << " Iterations)"
            << std::endl
            << std::endl;

  // print table header
  std::cout << std::left << std::setw(col_width) << std::setfill(space)
            << "Size";
  for (int instance = 0; instance < instances; instance++) {
    snprintf(text, 20, "Instance %i", instance);
    std::cout << std::left << std::setw(col_width) << std::setfill(space)
              << text;
  }
  std::cout << std::left << std::setw(col_width) << std::setfill(space)
            << "Total";
  std::cout << std::endl;

  // execute batch benchmark for different transfer sizes
  for (size_t s = batch_min_length; s <= batch_max_length; s++) {
    snprintf(text, 20, "%iKib", ((1 << s) / 1024));
    std::cout << std::left << std::setw(col_width) << std::setfill(space)
              << text;
    // execute Batch Read/Write
    executeBatchBenchmark(tapasco, designclk, 2, s, instances);

    std::cout << std::endl;
  }
}

int main(int argc, char **argv) {
  // Initialize TaPaSCo
  tapasco::Tapasco tapasco;

  // Check PE count
  uint64_t instances = tapasco.kernel_pe_count(PE_ID);
  std::cout << "Got " << instances << " instances @ "
            << tapasco.design_frequency() << "MHz" << std::endl;
  if (!instances || instances < 2) {
    std::cout << "Need at least two instance to run." << std::endl;
    exit(1);
  }

  // runtime for random access benchmark
  unsigned long cycles = random_time_ms * tapasco.design_frequency() * 1000;

  benchmarkRandom(tapasco, tapasco.design_frequency(), cycles, instances);

  benchmarkBatch(tapasco, tapasco.design_frequency(), instances);

  return 0;
}
