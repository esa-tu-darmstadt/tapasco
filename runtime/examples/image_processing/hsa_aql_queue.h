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
#ifndef HSA_AQL_QUEUE_H
#define HSA_AQL_QUEUE_H

#include <vector>

#include <hsa_ioctl_calls.h>

class aql_queue {
public:
  aql_queue() : fd(0), dma_mem(0) {
    // Open the driver provided file
    fd = open("/dev/HSA_AQL_QUEUE_0", O_RDWR, 0);
    if (fd < 0) {
      std::cout << "Could not open HSA_AQL_QUEUE_0" << std::endl;
      throw 1;
    }

    // Map the coherent address space into user space
    // The structure is defined in hsa_ioctl_calls.h
    dma_mem = (hsa_mmap_space *)mmap(0, sizeof(hsa_mmap_space),
                                     PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (dma_mem == MAP_FAILED) {
      std::cout << "Couldn't get mapping" << std::endl;
      throw 1;
    }
  }

  virtual ~aql_queue() {
    if (dma_mem)
      munmap((void *)dma_mem, sizeof(hsa_mmap_space));
    if (fd)
      close(fd);
  }

  void allocate_signal(hsa_ioctl_params *signal) {
    if (ioctl(fd, IOCTL_CMD_HSA_SIGNAL_ALLOC, signal)) {
      std::cout << "Could not allocate signal." << std::endl;
      throw 1;
    }
  }

  void deallocate_signal(hsa_ioctl_params signal) {
    if (ioctl(fd, IOCTL_CMD_HSA_SIGNAL_DEALLOC, &signal)) {
      std::cout << "Could not deallocate signal." << std::endl;
      throw 1;
    }
  }

  uint64_t *get_signal_userspace(hsa_ioctl_params &signal) {
    return &dma_mem->signals[signal.offset];
  }

  uint64_t get_signal_device(hsa_ioctl_params &signal) {
    return (uint64_t)signal.addr;
  }

  void *get_package_queue() { return dma_mem->queue; }

  void set_doorbell(hsa_ioctl_params signal) {
    if (ioctl(fd, IOCTL_CMD_HSA_DOORBELL_ASSIGN, &signal)) {
      std::cout << "Failed to set doorbell in hardware." << std::endl;
      throw 1;
    }
  }

  void unset_doorbell(hsa_ioctl_params signal) {
    if (ioctl(fd, IOCTL_CMD_HSA_DOORBELL_UNASSIGN, &signal)) {
      std::cout << "Failed to unset doorbell in hardware." << std::endl;
      throw 1;
    }
  }

private:
  int fd;
  hsa_mmap_space *dma_mem;
};

#endif
