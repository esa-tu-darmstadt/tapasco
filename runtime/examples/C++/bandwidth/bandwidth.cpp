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
#include <chrono>
#include <iostream>
#include <vector>

#include <tapasco.hpp>

using namespace tapasco;

int main(int argc, char **argv) {
  size_t max_pow = 30;
  size_t data_to_transfer = 256 * 1024 * 1024L;

  Tapasco tapasco;

  for (size_t s = 12; s < max_pow; ++s) {
    size_t len = 1 << s;
    size_t elements = std::max((size_t)1, len / sizeof(int));

    std::vector<int> arr_to(elements, 42);
    std::vector<int> arr_from(elements, 42);

    // get fpga handle
    tapasco_handle_t handle_to;
    tapasco.alloc(handle_to, len);

    tapasco_handle_t handle_from;
    tapasco.alloc(handle_from, len);

    size_t copied = 0;

    std::cout << "Write C " << len << "B @ ";
    auto start = std::chrono::system_clock::now();
    while (copied < data_to_transfer) {
      tapasco.copy_to((uint8_t *)arr_to.data(), handle_to, len);
      copied += len;
    }
    auto end = std::chrono::system_clock::now();

    std::chrono::duration<double> elapsed_seconds = end - start;

    std::cout << (data_to_transfer / elapsed_seconds.count()) /
                     (1024.0 * 1024.0)
              << "MBps" << std::endl;

    copied = 0;
    std::cout << "Read C " << len << "B @ ";
    start = std::chrono::system_clock::now();
    while (copied < data_to_transfer) {
      tapasco.copy_from(handle_from, (uint8_t *)arr_from.data(), len);
      copied += len;
    }
    end = std::chrono::system_clock::now();

    elapsed_seconds = end - start;

    std::cout << (data_to_transfer / elapsed_seconds.count()) /
                     (1024.0 * 1024.0)
              << "MBps" << std::endl;

    copied = 0;
    std::cout << "ReadWrite C " << len << "B @ ";
    while (copied < data_to_transfer) {
      tapasco.copy_to((uint8_t *)arr_to.data(), handle_to, len);
      tapasco.copy_from(handle_from, (uint8_t *)arr_from.data(), len);
      copied += len * 2;
    }
    end = std::chrono::system_clock::now();

    elapsed_seconds = end - start;

    std::cout << ((data_to_transfer * 2) / elapsed_seconds.count()) /
                     (1024.0 * 1024.0)
              << "MBps" << std::endl;

    tapasco.free(handle_to);
    tapasco.free(handle_from);
  }

  return 0;
}
