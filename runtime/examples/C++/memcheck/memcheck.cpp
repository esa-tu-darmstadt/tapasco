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
#include <algorithm>
#include <iostream>
#include <vector>

#ifdef _OPENMP
#include <omp.h>
#include <sstream>
#endif

#include <tapasco.hpp>

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
  int max_pow = 28;

  Tapasco tapasco;

  int threads = 1;

#ifdef _OPENMP
  if (argc > 1) {
    std::stringstream s(argv[1]);
    s >> threads;
  }
  omp_set_num_threads(threads);
#endif

  std::cout << "Using " << threads << " threads." << std::endl;

#ifdef _OPENMP
#pragma omp parallel for reduction(+ : errs)
#endif
  for (int s = 0; s < max_pow; ++s) {
    size_t len = 1 << s;
    std::cout << "Checking array size " << len << "B" << std::endl;
    size_t elements = std::max((size_t)1, len / sizeof(int));
    auto arr = init_array(elements);

    std::vector<int> rarr(elements, 42);

    // get fpga handle
    tapasco_handle_t h;
    tapasco.alloc(h, len);

    // copy data to and back
    tapasco.copy_to((uint8_t *)arr.data(), h, len);
    tapasco.copy_from(h, (uint8_t *)rarr.data(), len);

    tapasco.free(h);

    int merr = compare_arrays(arr, rarr, elements);
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
