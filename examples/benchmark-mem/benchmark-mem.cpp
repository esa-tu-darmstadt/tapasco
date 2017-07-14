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
//! @file  benchmark-mem.c
//! @brief  TPC API application that performs a simplistic benchmark on the
//!    memory system: 1GiB of data is transferred in chunks of sizes 
//!    ranging from 2^12 (== 4KiB) to 2^26 (== 64MiB) with one thread
//!    per processor. Each thread performs alloc-copy-dealloc until all
//!    transfers are finished; this is done in three modes read, write
//!    and read+write (data is either only copied from, copied to or
//!    copied in both directions).
//!    The program output can be used for the gnuplot script in this
//!    directory to generate a bar plot.
//! @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <iostream>
#include <fstream>
#include <thread>
#include <future>
#include <vector>
#include <string>
#include <cstring>
#include <chrono>
#include <unistd.h>
#include <cassert>
#include <atomic>
#include <tapasco.hpp>

constexpr size_t TRANSFER_SZ {1024*1024*1024};
constexpr size_t RNDDATA_SZ  {TRANSFER_SZ / 32};
constexpr unsigned long UPPER_BND {25};
constexpr unsigned long LOWER_BND {12};

using namespace std;

typedef unsigned long int ul;
typedef long int l;

static uint8_t     *rnddata;
static ul          chunk_sz;
static atomic<l>   transfers;
static atomic<ul>  errors;
static l           mode;

static tapasco::Tapasco Tapasco { false };

inline tapasco::tapasco_device_copy_flag_t operator|(tapasco::tapasco_device_copy_flag_t a,
		tapasco::tapasco_device_copy_flag_t b) {
	return static_cast<tapasco::tapasco_device_copy_flag_t>(static_cast<int>(a) | static_cast<int>(b));
}

static void fill_with_random(char *d, size_t const sz)
{
  auto start = chrono::steady_clock::now();
  ifstream ifs("/dev/urandom", ifstream::in);
  ifs.read(d, sz);
  auto dur = chrono::duration_cast<chrono::microseconds>(chrono::steady_clock::now() - start);
  cerr << "fill_with_random took " << dur.count() << " us." << endl;
}

static inline void baseline_transfer(void *d)
{
  if (! d) {
    errors++;
    return;
  }
  auto h = new (nothrow) uint8_t[chunk_sz];
  if (! h) {
    errors++;
    return;
  }

  switch (mode) {
  case 0:  /* read-only */
    memcpy(h, d, chunk_sz);
    break;
  case 1: /* write-only */
    memcpy(d, h, chunk_sz);
    break;
  case 2: /* read-write */
    memcpy(d, h, chunk_sz);
    memcpy(h, d, chunk_sz);
    break;
  }
  delete[] h;
}

static inline void tapasco_transfer(void *d)
{
  tapasco::tapasco_handle_t h = 0;
  if (! d) {
    errors++;
    return;
  }
  if (Tapasco.alloc(h, chunk_sz, tapasco::TAPASCO_DEVICE_ALLOC_FLAGS_NONE) != tapasco::TAPASCO_SUCCESS) {
    errors++;
    return;
  }

  switch (mode - 3) {
  case 0:  /* read-only */
    if (Tapasco.copy_from(h, d, chunk_sz, tapasco::TAPASCO_DEVICE_COPY_BLOCKING) != tapasco::TAPASCO_SUCCESS)
      errors++;
    break;
  case 1: /* write-only */
    if (Tapasco.copy_to(d, h, chunk_sz, tapasco::TAPASCO_DEVICE_COPY_BLOCKING) != tapasco::TAPASCO_SUCCESS)
      errors++;
    break;
  case 2: /* read-write */
    if (Tapasco.copy_to(d, h, chunk_sz, tapasco::TAPASCO_DEVICE_COPY_BLOCKING) == tapasco::TAPASCO_SUCCESS) {
      if (Tapasco.copy_from(h, d, chunk_sz, tapasco::TAPASCO_DEVICE_COPY_BLOCKING) != tapasco::TAPASCO_SUCCESS)
        errors++;
    } else errors++;
    break;
  }
  if (h) Tapasco.free(h, tapasco::TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
}

static void transfer()
{
  l i {0};
  while ((i = --transfers) > 0) {
    const ul off = (i % (RNDDATA_SZ / chunk_sz)) * chunk_sz;
    assert(off + chunk_sz <= RNDDATA_SZ);
    if (mode < 3)
      baseline_transfer(&rnddata[off]);
    else
      tapasco_transfer(&rnddata[off]);
  }
}

static void print_header(void)
{
  cout << "Allocation Size (KiB),virt. R (MiB/s),virt. W (MiB/s),virt. R+W (MiB/s),DMA R (MiB/s),DMA W (MiB/s),DMA R+W (MiB/s)" << endl;
}

static void print_line(ul const *times)
{
  cout << chunk_sz / 1024 << ", "
       << (TRANSFER_SZ/(1024*1024)) / (times[0] / 1000000.0) << ", "
       << (TRANSFER_SZ/(1024*1024)) / (times[1] / 1000000.0) << ", "
       << (TRANSFER_SZ/(1024*1024)) / (times[2] / 1000000.0) << ", "
       << (TRANSFER_SZ/(1024*1024)) / (times[3] / 1000000.0) << ", "
       << (TRANSFER_SZ/(1024*1024)) / (times[4] / 1000000.0) << ", "
       << (TRANSFER_SZ/(1024*1024)) / (times[5] / 1000000.0)
       << endl;
}

int main(int argc, char **argv)
{
  int i;
  ul times[6] = { 0 };

  // init timer and data
  rnddata = new uint8_t[RNDDATA_SZ];
  fill_with_random((char *)rnddata, RNDDATA_SZ);

  // initialize threadpool
  Tapasco.init(0);

  print_header();
  auto total_start = chrono::steady_clock::now();
  for (auto pw = UPPER_BND; pw >= LOWER_BND; --pw) {
    chunk_sz = static_cast<size_t>(1 << pw);
    for (mode = 0; mode <= 5; ++mode) {
      vector<future<void> > fs;
      transfers = TRANSFER_SZ / chunk_sz;
      errors = 0;
      auto run_start = chrono::steady_clock::now();
      for (i = 0; i < sysconf(_SC_NPROCESSORS_CONF); ++i)
        fs.push_back(async(launch::async, transfer));
      for (auto& f : fs) f.get();
      auto run_d = chrono::duration_cast<chrono::microseconds>(chrono::steady_clock::now() - run_start);
      times[mode] = errors ? 0 : run_d.count();
      if (mode % 3 == 2) times[mode] /= 2;
    }
    print_line(times);
  }
  auto total_d = chrono::duration_cast<chrono::microseconds>(chrono::steady_clock::now() - total_start);
  cerr << "Total duration: " << total_d.count() << " us." << endl;
  delete[] rnddata;
}
