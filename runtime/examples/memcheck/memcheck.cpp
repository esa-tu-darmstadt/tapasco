#include <algorithm>
#include <iostream>
#include <vector>

#include <tapasco.hpp>

using namespace tapasco;

std::vector<int> init_array(size_t sz) {
  std::vector<int> vec;
  for (size_t i = 0; i < sz; ++i) {
    vec.push_back(i);
  }
  return vec;
}

int compare_arrays(const std::vector<int> &arr, const std::vector<int> &rarr,
                   size_t const sz) {
  int errs = 0;
  for (size_t i = 0; i < sz; ++i) {
    if (rarr[i] != arr[i]) {
      std::cout << "wrong data: arr[" << i << "] = " << arr[i]
                << " != " << rarr[i] << " = rarr[" << i << "]" << std::endl;
      ++errs;
    }
  }
  return errs;
}

int main(int argc, char **argv) {
  int errs = 0;
  int max_pow = 28;

  Tapasco tapasco;

  for (int s = 0; s < max_pow && errs == 0; ++s) {
    size_t len = 1 << s;
    std::cout << "Checking array size " << len << "B" << std::endl;
    size_t elements = std::max((size_t)1, len / sizeof(int));
    auto arr = init_array(elements);

    std::vector<int> rarr(elements, 42);

    // get fpga handle
    tapasco_handle_t h;
    tapasco.alloc(h, len, (tapasco_device_alloc_flag_t)0);

    // copy data to and back
    tapasco.copy_to(arr.data(), h, len, (tapasco_device_copy_flag_t)0);
    tapasco.copy_from(h, rarr.data(), len, (tapasco_device_copy_flag_t)0);

    tapasco.free(h, len, (tapasco_device_alloc_flag_t)0);

    int merr = compare_arrays(arr, rarr, elements);
    errs = +merr;

    if (!merr)
      std::cout << "Array size " << len << "B ok!" << std::endl;
    else
      std::cout << "FAILURE: array size " << len << "B not ok." << std::endl;
  }

  if (!errs)
    std::cout << "SUCCESS" << std::endl;
  else
    std::cout << "FAILURE" << std::endl;

  return errs;
}
