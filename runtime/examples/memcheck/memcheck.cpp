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
//!		Single-threaded variant.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <iostream>
#include <tapasco.hpp>
#include <vector>

using namespace tapasco;

std::vector<int> init_array(size_t sz) {
  std::vector<int> vec;
  for (size_t i = 0; i < sz; ++i) {
    vec.push_back(i);
  }
  return vec;
}

int compare_arrays(const std::vector<int> &arr, const std::vector<int> &rarr,
                   size_t const sz) {
  int errs = 0;
  for (size_t i = 0; i < sz; ++i) {
    if (rarr[i] != arr[i]) {
      std::cout << "wrong data: arr[" << i << "] = " << arr[i]
                << " != " << rarr[i] << " = rarr[" << i << "]" << std::endl;
      ++errs;
    }
  }
  return errs;
}

int main(int argc, char **argv) {
  int errs = 0;
  int max_pow = 20;

  Tapasco tapasco;

  for (int s = 0; s < max_pow && errs == 0; ++s) {
    size_t len = 1 << s;
    std::cout << "Checking array size " << len << "B" << std::endl;
    auto arr = init_array(len / sizeof(int));

    std::vector<int> rarr(len / 4, 42);

    // get fpga handle
    tapasco_handle_t h;
    tapasco.alloc(h, len, (tapasco_device_alloc_flag_t)0);
    std::cout << "handle = 0x" << std::hex << (unsigned long)h << std::dec
              << std::endl;

    // copy data to and back
    tapasco.copy_to(arr.data(), h, len, (tapasco_device_copy_flag_t)0);
    tapasco.copy_from(h, rarr.data(), len, (tapasco_device_copy_flag_t)0);

    tapasco.free(h, len, (tapasco_device_alloc_flag_t)0);

    int merr = compare_arrays(arr, rarr, len);
    errs = +merr;

    if (!merr)
      std::cout << "Array size " << len << "B ok!" << std::endl;
    else
      std::cout << "FAILURE: array size " << len << "B not ok." << std::endl;
  }

  if (!errs)
    std::cout << "SUCCESS" << std::endl;
  else
    std::cout << "FAILURE" << std::endl;

  return errs;
}
