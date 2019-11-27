#include <chrono>
#include <iostream>

#include <platform_types.h>
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
