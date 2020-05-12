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
#include <chrono>
#include <iostream>

#include <tapasco.hpp>

using namespace tapasco;

extern volatile void *
device_regspace_status_ptr(const platform_devctx_t *devctx);

int main(int argc, char **argv) {
  Tapasco tapasco;

  constexpr int repetitions = 1000000;

  volatile void *status = device_regspace_status_ptr(tapasco.platform_device());

  std::chrono::duration<double, std::nano> elapsed_seconds;

  volatile uint64_t out;

  auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < repetitions; ++i) {
    out = ((volatile uint64_t *)status)[0];
  }
  auto end = std::chrono::steady_clock::now();

  elapsed_seconds = end - start;
  uint64_t read_delay = (uint64_t)(elapsed_seconds.count() / repetitions);
  std::cout << std::fixed << "Single read takes " << read_delay
            << "ns. V: " << out << std::endl;

  start = std::chrono::steady_clock::now();
  for (int i = 0; i < repetitions; ++i) {
    ((volatile uint64_t *)status)[0] = 42;
  }
  end = std::chrono::steady_clock::now();

  elapsed_seconds = end - start;
  uint64_t write_delay = (uint64_t)(elapsed_seconds.count() / repetitions);
  std::cout << std::fixed << "Single write takes " << write_delay
            << "ns. V: " << out << std::endl;

  return 0;
}
