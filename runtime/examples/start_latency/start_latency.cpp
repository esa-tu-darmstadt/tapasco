#include <chrono>
#include <iostream>

#include <platform_types.h>
#include <tapasco.hpp>

using namespace tapasco;

extern volatile void *device_regspace_status_ptr(const platform_devctx_t *devctx);

int main(int argc, char **argv) {
  Tapasco tapasco;

  constexpr int repetitions = 1000;

  static constexpr tapasco_kernel_id_t LATENCY_ID{742};

  uint64_t instances = tapasco_device_kernel_pe_count(tapasco.device(), LATENCY_ID);
  if (instances != 1) {
    std::cout << "Need exactly one latency instance to run." << std::endl;
    exit(1);
  }

  platform_info_t info;
  tapasco.info(&info);

  platform_ctl_addr_t pe_addr = 0;

  for (int i = 0; i < PLATFORM_NUM_SLOTS; ++i) {
    if (info.composition.kernel[i] == LATENCY_ID) {
      pe_addr = info.base.arch[i];
    }
  }

  std::cout << "Found pe at 0x" << std::hex << pe_addr << std::dec << std::endl;
  platform_ctl_addr_t pe_addr_reg = pe_addr + 0x20 + 9 * 0x10;
  std::cout << "Using parameter 10 to set time at 0x" << std::hex << pe_addr_reg << std::dec << std::endl;

  volatile void *status = device_regspace_status_ptr(tapasco.platform_device());

  std::chrono::duration<double, std::nano> elapsed_seconds;

  volatile uint64_t out;

  auto start = std::chrono::system_clock::now();
  for (int i = 0; i < repetitions; ++i) {
    out = ((volatile uint64_t*)status)[0];
  }
  auto end = std::chrono::system_clock::now();

  elapsed_seconds = end - start;
  uint64_t read_delay = (uint64_t) (elapsed_seconds.count() / repetitions);
  std::cout << std::fixed << "Single read takes " << read_delay << "us. V: " << out << std::endl;

  start = std::chrono::system_clock::now();
  for (int i = 0; i < repetitions; ++i) {
    ((volatile uint64_t*)status)[0] = 42;
  }
  end = std::chrono::system_clock::now();

  elapsed_seconds = end - start;
  uint64_t write_delay = (uint64_t) (elapsed_seconds.count() / repetitions);
  std::cout << std::fixed << "Single write takes " << write_delay << "us. V: " << out << std::endl;

  uint64_t ret = -1;
  RetVal<uint64_t> ret_ts(ret);

  auto sync = std::chrono::system_clock::now();
  auto start_e = sync.time_since_epoch();
  uint64_t start_t = start_e.count();
  platform_write_ctl(tapasco.platform_device(), pe_addr_reg, sizeof(uint64_t), (void*)start_t, PLATFORM_CTL_FLAGS_NONE);

  start = std::chrono::system_clock::now();
  auto job = tapasco.launch(LATENCY_ID, ret_ts, 1);
  job();

  std::cout << "Start host " << start_t << " start PE " << start.time_since_epoch().count() << std::endl;

  return 0;
}
