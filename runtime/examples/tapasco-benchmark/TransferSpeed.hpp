/**
 *  @file TransferSpeed.hpp
 *  @brief  Measures the transfer speed via TPC for a given chunk size.
 *  @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TRANSFER_SPEED_HPP__
#define TRANSFER_SPEED_HPP__

#include <atomic>
#include <chrono>
#include <cmath>
#include <future>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>
#include <tapasco.hpp>
#include <thread>
#include <unistd.h>
#include <vector>

using namespace std;
using namespace std::chrono;
using namespace tapasco;

/** Measurement class that can measure TaPaSCo memory transfer speeds. **/
class TransferSpeed {
public:
  TransferSpeed(Tapasco &tapasco, bool fast) : tapasco(tapasco), fast(fast) {}
  virtual ~TransferSpeed() {}

  static constexpr long OP_ALLOCFREE = 0;
  static constexpr long OP_COPYFROM = 1;
  static constexpr long OP_COPYTO = 2;

  double operator()(size_t const chunk_sz, long const opmask = 3) {
    CumulativeAverage<double> cavg{0};
    atomic<bool> stop{false};
    double const cs{chunk_sz / 1024.0};
    string const ms{maskToString(opmask)};
    double b{0.0};

    bytes = 0;

    auto tstart{high_resolution_clock::now()};
    duration<double> d{high_resolution_clock::now() - tstart};
    future<void> f{
        async(launch::async, [&]() { transfer(stop, chunk_sz, opmask); })};
    double delta = 0.0;
    do {
      std::ios_base::fmtflags coutf(cout.flags());
      if (cs <= 1024) {
        std::cout << "\rChunk size: " << std::dec << std::fixed << std::setw(10)
                  << std::setprecision(0) << cs << " KiB, Mask: ";
      } else {
        std::cout << "\rChunk size: " << std::dec << std::fixed << std::setw(10)
                  << std::setprecision(0) << (cs / 1024.0) << " MiB, Mask: ";
      }
      std::cout << std::dec << ms.c_str() << ", Precision: " << std::dec
                << std::fixed << std::setw(6) << std::setprecision(2) << delta
                << ", Samples: " << std::dec << std::setw(3) << cavg.size()
                << ", Speed: " << std::dec << std::fixed << std::setw(9)
                << std::setprecision(3) << cavg() << " MiB/s" << std::flush;
      cout.flags(coutf);
      usleep(10000);
      b = bytes.load() / (1024.0 * 1024.0);
      d = high_resolution_clock::now() - tstart;
      delta = fabs(cavg.update(b / d.count()));
    } while (((!fast && delta > 0.1) || cavg.size() < 100 ||
              (bytes.load() <= 2 * chunk_sz)));

    stop = true;
    f.get();

    std::ios_base::fmtflags coutf(cout.flags());
    if (cs <= 1024) {
      std::cout << "\rChunk size: " << std::dec << std::fixed << std::setw(10)
                << std::setprecision(0) << cs << " KiB, Mask: ";
    } else {
      std::cout << "\rChunk size: " << std::dec << std::fixed << std::setw(10)
                << std::setprecision(0) << (cs / 1024.0) << " MiB, Mask: ";
    }
    std::cout << std::dec << ms.c_str() << ", Precision: " << std::dec
              << std::fixed << std::setw(6) << std::setprecision(2) << delta
              << ", Samples: " << std::dec << std::setw(3) << cavg.size()
              << ", Speed: " << std::dec << std::fixed << std::setw(9)
              << std::setprecision(3) << cavg() << " MiB/s" << std::flush;
    cout.flags(coutf);

    std::cout << std::endl;

    return cavg();
  }

private:
  tapasco_res_t do_read(volatile atomic<bool> &stop, size_t const chunk_sz,
                        long opmask, uint8_t *data) {
    if (!(opmask & OP_COPYFROM))
      return TAPASCO_SUCCESS;
    tapasco_handle_t h;
    tapasco_res_t r{
        tapasco.alloc(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE)};
    if (r != TAPASCO_SUCCESS) {
      return r;
    }
    while (!stop.load()) {
      r = tapasco.copy_from(h, data, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
      if (r != TAPASCO_SUCCESS) {
        stop = true;
      } else {
        bytes += chunk_sz;
      }
    }
    tapasco.free(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
    return r;
  }

  tapasco_res_t do_write(volatile atomic<bool> &stop, size_t const chunk_sz,
                         long opmask, uint8_t *data) {
    if (!(opmask & OP_COPYTO))
      return TAPASCO_SUCCESS;
    tapasco_handle_t h;
    tapasco_res_t r{
        tapasco.alloc(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE)};
    if (r != TAPASCO_SUCCESS) {
      return r;
    }
    while (!stop.load()) {
      r = tapasco.copy_to(data, h, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
      if (r != TAPASCO_SUCCESS) {
        stop = true;
      } else {
        bytes += chunk_sz;
      }
    }
    tapasco.free(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
    return r;
  }

  void transfer(volatile atomic<bool> &stop, size_t const chunk_sz,
                long opmask) {
    std::vector<uint8_t> data_read(chunk_sz);
    for (auto &i : data_read)
      i = rand();

    std::vector<uint8_t> data_write(chunk_sz);
    for (auto &i : data_write)
      i = rand();

    std::thread readthread(&TransferSpeed::do_read, this, std::ref(stop),
                           chunk_sz, opmask, data_read.data());
    std::thread writethread(&TransferSpeed::do_write, this, std::ref(stop),
                            chunk_sz, opmask, data_write.data());

    readthread.join();
    writethread.join();
  }

  static const std::string maskToString(long const opmask) {
    stringstream tmp;
    tmp << (opmask & OP_COPYFROM ? "r" : " ")
        << (opmask & OP_COPYTO ? "w" : " ");
    return tmp.str();
  }

  atomic<uint64_t> bytes{0};
  Tapasco &tapasco;
  bool fast;
};

#endif /* TRANSFER_SPEED_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
