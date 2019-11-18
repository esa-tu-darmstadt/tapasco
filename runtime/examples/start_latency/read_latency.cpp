#include <chrono>
#include <iostream>

#include <platform_types.h>
#include <tapasco.hpp>

using namespace tapasco;

int main(int argc, char **argv) {
  Tapasco tapasco;

  constexpr int repetitions = 1000;

  static constexpr tapasco_kernel_id_t COUNTER_ID{14};

  extern volatile void *device_regspace_status_ptr(const platform_devctx_t *devctx);

  uint64_t instances = tapasco_device_kernel_pe_count(tapasco.device(), COUNTER_ID);
  if (!instances) {
    std::cout << "Need at least one counter instance to run.";
    exit(1);
  }

  volatile void *status = device_regspace_status_ptr(tapasco.platform_device());

  std::chrono::duration<double> elapsed_seconds;

  volatile uint64_t out;

  auto start = std::chrono::system_clock::now();
  for (int i = 0; i < repetitions; ++i) {
    out = ((volatile uint64_t*)status)[0];
  }
  auto end = std::chrono::system_clock::now();

  elapsed_seconds = end - start;
  std::cout << std::fixed << "Single read takes " << elapsed_seconds.count() / repetitions << "s. V: " << out << std::endl;

  start = std::chrono::system_clock::now();
  for (int i = 0; i < repetitions; ++i) {
    ((volatile uint64_t*)status)[0] = 42;
  }
  end = std::chrono::system_clock::now();

  elapsed_seconds = end - start;
  std::cout << std::fixed << "Single write takes " << elapsed_seconds.count() / repetitions << "s. V: " << out << std::endl;

  return 0;
}
