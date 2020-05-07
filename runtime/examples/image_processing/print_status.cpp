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
#include <atomic>
#include <chrono>
#include <csignal>
#include <ctime>
#include <fcntl.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <signal.h>
#include <sstream>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <vector>

int main(int argc, const char *argv[]) {
  int fd = open("/dev/HSA_AQL_QUEUE_0", O_RDWR, 0);
  if (fd < 0) {
    std::cout << "Could not open HSA_AQL_QUEUE_0" << std::endl;
    return -1;
  }
  uint64_t *arbiter_space = (uint64_t *)mmap(0, 0x1000, PROT_READ | PROT_WRITE,
                                             MAP_SHARED, fd, 2 * getpagesize());
  if (arbiter_space == MAP_FAILED) {
    std::cout << "Couldn't get mapping" << std::endl;
    return -1;
  }

  uint64_t *signal_space = (uint64_t *)mmap(0, 0x1000, PROT_READ | PROT_WRITE,
                                            MAP_SHARED, fd, 3 * getpagesize());
  if (signal_space == MAP_FAILED) {
    std::cout << "Couldn't get mapping" << std::endl;
    return -1;
  }

  std::cout << "Waiting for completion" << std::endl;

  for (int i = 0; i < 64; ++i) {
    std::cout << i << " " << std::hex << signal_space[i] << std::dec
              << std::endl;
  }

  // Print some status registers for debugging
  // Counter for signal sent and acked, should be equal
  std::cout << "Idle cycles " << arbiter_space[11] << std::endl;

  std::cout << "Fetch iterations " << arbiter_space[10] << std::endl;

  std::cout << "Packages Fetched is " << arbiter_space[22] << std::endl;

  std::cout << "Packages Invalidated is " << arbiter_space[23] << std::endl;

  std::cout << "Read_index is " << arbiter_space[24] << std::endl;

  std::cout << "Read_index_old is " << arbiter_space[25] << std::endl;

  std::cout << "Write_index is " << arbiter_space[26] << std::endl;

  std::cout << "Write_index_old is " << arbiter_space[27] << std::endl;

  munmap(arbiter_space, 0x1000);
  munmap(signal_space, 0x1000);
  close(fd);

  return EXIT_SUCCESS;
}
