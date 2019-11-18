#include <algorithm>
#include <chrono>
#include <iostream>
#include <vector>

#ifdef _OPENMP
#include <omp.h>
#include <sstream>
#endif

#include <tapasco.hpp>

using namespace tapasco;

int main(int argc, char **argv) {
  Tapasco tapasco;

  constexpr int max_pow = 30;
  constexpr int repetitions = 1000;

int threads = 1;

#ifdef _OPENMP
  if (argc > 1) {
    std::stringstream s(argv[1]);
    s >> threads;
  }
  omp_set_num_threads(threads);
#endif

  std::cout << "Using " << threads << " threads." << std::endl;

  static constexpr tapasco_kernel_id_t COUNTER_ID{14};

  uint64_t instances = tapasco_device_kernel_pe_count(tapasco.device(), COUNTER_ID);
  if (!instances) {
    std::cout << "Need at least one arrayinit instance to run.";
    exit(1);
  }


  std::chrono::duration<double> elapsed_seconds;

  std::cout << "Byte, Seconds" << std::endl;

  for (size_t s = 3; s < max_pow; ++s) {
    size_t len = 1 << s;

    size_t elements = std::max((size_t)1, len / sizeof(int));
    std::vector<int> arr_from(elements, -1);

    // Wrap the array to be TaPaSCo compatible
    auto result_buffer_pointer = tapasco::makeWrappedPointer(
                                   arr_from.data(), arr_from.size() * sizeof(int));
    // Data will be copied back from the device only, no data will be moved to
    // the device
    auto result_buffer_out = tapasco::makeOutOnly(result_buffer_pointer);

#ifdef _OPENMP
    #pragma omp parallel for shared(elapsed_seconds)
#endif
    for (int i = 0; i < repetitions; ++i) {
      if (len > 8) {
        auto start = std::chrono::system_clock::now();
        auto job = tapasco.launch(COUNTER_ID, 1, result_buffer_out);
        job();
        auto end = std::chrono::system_clock::now();
        elapsed_seconds += end - start;
      } else {
        uint64_t v = 0;
        RetVal<uint64_t> ret(v);
        auto start = std::chrono::system_clock::now();
        auto job = tapasco.launch(COUNTER_ID, v, 1);
        job();
        auto end = std::chrono::system_clock::now();
        elapsed_seconds += end - start;
      }
    }
    std::cout << std::fixed << len << "," << elapsed_seconds.count() / repetitions << std::endl;
  }

  return 0;
}
