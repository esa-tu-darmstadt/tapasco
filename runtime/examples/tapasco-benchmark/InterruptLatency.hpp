/**
 *  @file InterruptLatency.hpp
 *  @brief  Measures the software overhead, i.e., the roundtrip time that is
 *              added by the TPC software layers. This is done via the 'Counter'
 *              IP cores, which simply provide a cycle-accurate countdown timer.
 *              The default design should provide at least one instance of the
 *              timer, which accepts a cycle count as first argument. The design
 *              should run at 100 Mhz (assumption of timing calculations).
 *  @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef INTERRUPT_LATENCY_HPP__
#define INTERRUPT_LATENCY_HPP__

#include <atomic>
#include <chrono>
#include <cmath>
#include <future>
#include <sstream>
#include <tapasco.hpp>
#include <thread>
#include <unistd.h>
#include <vector>
extern "C" {
#include <platform.h>
}

using namespace std;
using namespace std::chrono;
using namespace tapasco;

/**
 * Measures interrupt latency added by software layers in TPC.
 **/
class InterruptLatency {
public:
  static tapasco_kernel_id_t const COUNTER_ID = 14;

  InterruptLatency(Tapasco &tapasco, bool fast) : tapasco(tapasco), fast(fast) {
    tapasco_res_t r;
    platform_info_t info;
    if (tapasco.kernel_pe_count(COUNTER_ID) == 0)
      throw "need at least one instance of 'Counter' (14) in bitstream";
    if ((r = tapasco.info(&info)) != TAPASCO_SUCCESS)
      throw new Tapasco::tapasco_error(r);
    if (r != PLATFORM_SUCCESS)
      throw Tapasco::platform_error(r);
    design_clk = info.clock.design;
  }
  virtual ~InterruptLatency() {}

  static constexpr long OP_ALLOCFREE = 0;
  static constexpr long OP_COPYFROM = 1;
  static constexpr long OP_COPYTO = 2;

  double atcycles(uint32_t const clock_cycles, size_t const min_runs = 100,
                  double *min = NULL, double *max = NULL) {
    CumulativeAverage<double> cavg{0};
    atomic<bool> stop{false};
    future<void> f =
        async(launch::async, [&]() { trigger(stop, clock_cycles, cavg); });
    do {
      std::ios_base::fmtflags coutf(cout.flags());
      std::cout << "\rRuntime: " << std::dec << std::fixed << std::setw(10)
                << std::setprecision(0) << clock_cycles
                << " cc, Latency: " << std::dec << std::fixed << std::setw(6)
                << std::setprecision(2) << cavg() << ", Max: " << std::dec
                << std::fixed << std::setw(6) << std::setprecision(2)
                << cavg.max() << ", Min: " << std::dec << std::fixed
                << std::setw(6) << std::setprecision(2) << cavg.min()
                << ", Precision: " << std::dec << std::fixed << std::setw(6)
                << std::setprecision(2) << fabs(cavg.delta())
                << ", Samples: " << std::dec << std::setw(3) << cavg.size()
                << std::flush;
      cout.flags(coutf);
      usleep(1000000);
    } while (((!fast && fabs(cavg.delta()) > 0.01) || cavg.size() < min_runs));
    stop = true;
    f.get();
    if (min)
      *min = cavg.min();
    if (max)
      *max = cavg.max();

    std::ios_base::fmtflags coutf(cout.flags());
    std::cout << "\rRuntime: " << std::dec << std::fixed << std::setw(10)
              << std::setprecision(0) << clock_cycles
              << " cc, Latency: " << std::dec << std::fixed << std::setw(6)
              << std::setprecision(2) << cavg() << ", Max: " << std::dec
              << std::fixed << std::setw(6) << std::setprecision(2)
              << cavg.max() << ", Min: " << std::dec << std::fixed
              << std::setw(6) << std::setprecision(2) << cavg.min()
              << ", Precision: " << std::dec << std::fixed << std::setw(6)
              << std::setprecision(2) << fabs(cavg.delta())
              << ", Samples: " << std::dec << std::setw(3) << cavg.size()
              << std::flush;
    cout.flags(coutf);

    std::cout << std::endl;

    return cavg();
  }

private:
  void trigger(volatile atomic<bool> &stop, uint32_t const clock_cycles,
               CumulativeAverage<double> &cavg) {
    tapasco_res_t res;
    while (!stop.load()) {
      auto tstart = high_resolution_clock::now();
      // if 0, use 1us - 100ms interval (clock period is 10ns)
      uint32_t cc =
          clock_cycles > 0 ? clock_cycles : (rand() % (10000000 - 100) + 100);
      if ((res = tapasco.launch(COUNTER_ID, cc)()) != TAPASCO_SUCCESS)
        throw Tapasco::tapasco_error(res);
      microseconds const d =
          duration_cast<microseconds>(high_resolution_clock::now() - tstart);
      cavg.update(d.count() - cc / design_clk);
    }
  }

  static const std::string maskToString(long const opmask) {
    stringstream tmp;
    tmp << (opmask & OP_COPYFROM ? "r" : " ")
        << (opmask & OP_COPYTO ? "w" : " ");
    return tmp.str();
  }

  uint32_t design_clk;
  Tapasco &tapasco;
  bool fast;
};

#endif /* INTERRUPT_LATENCY_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
