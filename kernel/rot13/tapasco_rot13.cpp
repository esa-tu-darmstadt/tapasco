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
 *  @file	tapasco-rot13.cpp
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <iostream>
#include <fstream>
#include <vector>
#include <future>
#include <atomic>
#include <assert.h>
#include <tapasco.hpp>

using namespace std;
using namespace tapasco;

#define __SYNTHESIS__
#include "rot13.cpp"

#define CHECK(x) assert((x) == TAPASCO_SUCCESS);

#ifndef __SYNTHESIS__
static constexpr size_t MAX_LEN = 4096;
#endif // __SYNTHESIS__

static char *read_file(char const *fn, size_t& file_sz)
{
  char *ret;
  ifstream f(fn, ifstream::in);
  // compute file length
  f.seekg(0, f.end);
  file_sz = f.tellg();
  f.seekg(0, f.beg);
  // allocate device memory
  ret = new char[file_sz];
  f.read(ret, file_sz);
  f.close();
  return ret;
}

int main(int argc, char *argv[])
{
  size_t sz;
  assert(argc > 1); 						// need filename
  Tapasco tapasco;						// init Tapasco
  char *filedata = read_file(argv[1], sz);			// read data
  atomic<long> nr_jobs { static_cast<long>
      (sz / MAX_LEN + (sz % MAX_LEN ? 1 : 0)) };		// number of jobs
  size_t const nr_threads = tapasco.func_instance_count(13);	// number PEs
  vector<future<void> > fs;					// futures
  char *text_out = new char[sz];				// out buffer

  for (size_t i = 0; i < nr_threads; ++i) {
    fs.push_back(async(launch::async, [&]() {
        long j_idx;
	while ((j_idx = --nr_jobs) >= 0) {
	  assert(j_idx < 34);
	  size_t const idx = j_idx * MAX_LEN;
	  size_t const isz = idx + MAX_LEN > sz ? sz % MAX_LEN : MAX_LEN;
	  assert(isz <= MAX_LEN);
	  (void)idx; (void)isz;

	  tapasco_handle_t h_in {0}, h_out {0};
	  CHECK( tapasco.alloc(h_in, isz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE) );
	  CHECK( tapasco.alloc(h_out, isz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE) );
	  CHECK( tapasco.copy_to(&filedata[idx], h_in, isz, TAPASCO_DEVICE_COPY_BLOCKING) );
	  CHECK( tapasco.launch_no_return(13, isz, h_in, h_out) );
	  CHECK( tapasco.copy_from(h_out, &text_out[idx], isz, TAPASCO_DEVICE_COPY_BLOCKING) );
	  tapasco.free(h_in, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
	  tapasco.free(h_out, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
	}
      }));
  }

  for (auto& f : fs)
    f.get();					// wait for threads to finish

  cout << text_out << endl;
  delete[] text_out;
  delete[] filedata;
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
