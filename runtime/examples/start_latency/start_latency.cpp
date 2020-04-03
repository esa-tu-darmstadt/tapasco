#include <chrono>
#include <iostream>
#include <vector>

#include <platform_types.h>
#include <tapasco.hpp>

#ifdef _OPENMP
#include <omp.h>
#include <sstream>
#endif

using namespace tapasco;

extern volatile void *
device_regspace_status_ptr(const platform_devctx_t *devctx);

int main(int argc, char **argv) {
  Tapasco tapasco;

  constexpr int max_pow = 30;
  constexpr int repetitions = 1000;

  static constexpr tapasco_kernel_id_t LATENCY_ID{742};

  int threads = 1;

#ifdef _OPENMP
  if (argc > 1) {
    std::stringstream s(argv[1]);
    s >> threads;
  }
  omp_set_num_threads(threads);
#endif

  std::cout << "Using " << threads << " threads." << std::endl;

  uint64_t instances =
      tapasco_device_kernel_pe_count(tapasco.device(), LATENCY_ID);
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
  std::cout << "Using parameter 10 to set time at 0x" << std::hex << pe_addr_reg
            << std::dec << std::endl;

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

  std::cout << "Starting experiment" << std::endl;

  std::cout << "Byte,Nanoseconds" << std::endl;

  for (size_t s = 3; s < max_pow; ++s) {
    uint64_t elapsed_seconds = 0;

    uint64_t ret = -1;
    RetVal<uint64_t> ret_ts(ret);

    size_t len = 1 << s;

    size_t elements = std::max((size_t)1, len / sizeof(int));
    std::vector<int> arr_from(elements, -1);

    // Wrap the array to be TaPaSCo compatible
    auto result_buffer_pointer = tapasco::makeWrappedPointer(
        arr_from.data(), arr_from.size() * sizeof(int));
    // Data will be copied back from the device only, no data will be moved to
    // the device
    auto result_buffer_in = tapasco::makeInOnly(result_buffer_pointer);

#ifdef _OPENMP
#pragma omp parallel for shared(elapsed_seconds)
#endif
    for (int i = 0; i < repetitions; ++i) {
      auto sync = std::chrono::steady_clock::now();
      uint64_t start_t = 1;
      platform_write_ctl(tapasco.platform_device(), pe_addr_reg,
                         sizeof(uint64_t), (void *)&start_t,
                         PLATFORM_CTL_FLAGS_NONE);

      // usleep(1);

      start = std::chrono::steady_clock::now();
      if (len > 8) {
        tapasco.launch(LATENCY_ID, ret_ts, result_buffer_in)();
      } else {
        tapasco.launch(LATENCY_ID, ret_ts, 1)();
      }
      std::chrono::duration<double, std::nano> diff = start - sync;
      double clock_period_ns = 1000.0 / info.clock.design;
      uint64_t start_period_ns = clock_period_ns * ret;
      elapsed_seconds = start_period_ns - diff.count() + (read_delay / 2);
      std::cout << std::fixed << len << "," << elapsed_seconds << std::endl;
    }
  }

  // Calculate the time it took from counter start (platform_write) to PE start
  // in nanoseconds

  // Assuming that the counter reset of the PE takes as long as the fetching of
  // the clock - high uncertainty Hence, only the counter period is relevant.
  /*
    // Calculate the Timestamp of the start of the PE
    //uint64_t start_ns = start.time_since_epoch().count() + start_period_ns;
    //uint64_t diff = start_ns - start.time_since_epoch().count();
  */
  return 0;
}