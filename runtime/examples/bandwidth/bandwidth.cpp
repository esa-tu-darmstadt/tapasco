#include <iostream>
#include <vector>
#include <algorithm>
#include <chrono>

#include <tapasco.hpp>

using namespace tapasco;

int main(int argc, char **argv) {
  size_t max_pow = 30;
  size_t data_to_transfer = 256*1024*1024L;

  Tapasco tapasco;

  for (size_t s = 12; s < max_pow; ++s) {
    size_t len = 1 << s;
    size_t elements = std::max((size_t)1, len / sizeof(int));

    std::vector<int> arr_to(elements, 42);
    std::vector<int> arr_from(elements, 42);

    // get fpga handle
    tapasco_handle_t handle_to;
    tapasco.alloc(handle_to, len, (tapasco_device_alloc_flag_t)0);

    tapasco_handle_t handle_from;
    tapasco.alloc(handle_from, len, (tapasco_device_alloc_flag_t)0);

    size_t copied = 0;

    std::cout << "Write C " << len << "B @ ";
    auto start = std::chrono::system_clock::now();
    while(copied < data_to_transfer) {
      tapasco.copy_to(arr_to.data(), handle_to, len, (tapasco_device_copy_flag_t)0);
      copied += len;
    }
    auto end = std::chrono::system_clock::now();

    std::chrono::duration<double> elapsed_seconds = end-start;

    std::cout << (data_to_transfer / elapsed_seconds.count()) / (1024.0 * 1024.0) << "MBps" << std::endl;

    copied = 0;
    std::cout << "Read C " << len<< "B @ ";
    start = std::chrono::system_clock::now();
    while(copied < data_to_transfer) {
      tapasco.copy_from(handle_from, arr_from.data(), len, (tapasco_device_copy_flag_t)0);
      copied += len;
    }
    end = std::chrono::system_clock::now();

    elapsed_seconds = end-start;

    std::cout << (data_to_transfer / elapsed_seconds.count()) / (1024.0 * 1024.0) << "MBps" << std::endl;

    copied = 0;
    std::cout << "ReadWrite C " << len << "B @ ";
    while(copied < data_to_transfer) {
      tapasco.copy_to(arr_to.data(), handle_to, len, (tapasco_device_copy_flag_t)0);
      tapasco.copy_from(handle_from, arr_from.data(), len, (tapasco_device_copy_flag_t)0);
      copied += len*2;
    }
    end = std::chrono::system_clock::now();

    elapsed_seconds = end-start;

    std::cout << ((data_to_transfer*2) / elapsed_seconds.count()) / (1024.0 * 1024.0) << "MBps" << std::endl;


    tapasco.free(handle_to, len, (tapasco_device_alloc_flag_t)0);
    tapasco.free(handle_from, len, (tapasco_device_alloc_flag_t)0);
  }

  return 0;
}
