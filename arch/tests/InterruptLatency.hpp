/**
 *  @file	InterruptLatency.hpp
 *  @brief	Measures the software overhead, i.e., the roundtrip time that is
 *              added by the TPC software layers. This is done via the 'Counter'
 *              IP cores, which simply provide a cycle-accurate countdown timer.
 *              The default design should provide at least one instance of the
 *              timer, which accepts a cycle count as first argument. The design
 *              should run at 100 Mhz (assumption of timing calculations).
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef INTERRUPT_LATENCY_HPP__
#define INTERRUPT_LATENCY_HPP__

#include <atomic>
#include <thread>
#include <future>
#include <vector>
#include <sstream>
#include <chrono>
#include <cmath>
#include <unistd.h>
#include <ncurses.h>
#include <tapasco.hpp>

using namespace std;
using namespace std::chrono;
using namespace tapasco;

/**
 * Measures interrupt latency added by software layers in TPC.
 **/
class InterruptLatency {
public:
  static tapasco_func_id_t const COUNTER_ID = 14;

  InterruptLatency(Tapasco& tapasco) : tapasco(tapasco) {
    if (tapasco.func_instance_count(COUNTER_ID) == 0)
      throw "need at least one instance of 'Counter' (14) in bitstream";
  }
  virtual ~InterruptLatency() {}

  static constexpr long OP_ALLOCFREE = 0;
  static constexpr long OP_COPYFROM  = 1;
  static constexpr long OP_COPYTO    = 2;

  double atcycles(uint32_t const clock_cycles, size_t const min_runs = 100, double *min = NULL, double *max = NULL) {
    CumulativeAverage<double> cavg { 0 };
    bool stop = false;
    int x, y, maxx, maxy;
    getyx(stdscr, y, x);
    getmaxyx(stdscr, maxy, maxx);
    future<void> f = async(launch::async, [&]() { trigger(stop, clock_cycles, cavg); });
    auto c = getch();
    do {
      move(y, 0);
      clrtoeol();
      mvprintw(y, x, "Runtime: %12zu cc, Latency: % 12.1f, Min: % 12.1f, Max: % 12.1f, Count: %zu/%zu",
        clock_cycles, cavg(), cavg.min(), cavg.max(), cavg.size(), min_runs);
      refresh();
      usleep(1000000);
      // exit gracefully on ctrl+c
      c = getch();
      if (c == 3) { endwin(); exit(3); }
    } while (c == ERR && (fabs(cavg.delta()) > 0.01 || cavg.size() < min_runs));
    stop = true;
    f.get();
    mvprintw(y, x, "Runtime: %12zu cc, Latency: % 12.1f, Min: % 12.1f, Max: % 12.1f, Count: %zu/%zu",
      clock_cycles, cavg(), cavg.min(), cavg.max(), cavg.size(), min_runs);
    refresh();

    move((y+1) % maxy, 0);
    if (min) *min = cavg.min();
    if (max) *max = cavg.max();
    return cavg();
  }

private:
  void trigger(volatile bool& stop, uint32_t const clock_cycles, CumulativeAverage<double>& cavg) {
    tapasco_res_t res;
    while (! stop) {
      auto tstart = high_resolution_clock::now();
      // if 0, use 1us - 100ms interval (clock period is 10ns)
      uint32_t cc = clock_cycles > 0 ? clock_cycles : (rand() % (10000000 - 100) + 100);
      if ((res = tapasco.launch_no_return(COUNTER_ID, cc)) != TAPASCO_SUCCESS)
        throw Tapasco::tapasco_error(res);
      microseconds const d = duration_cast<microseconds>(high_resolution_clock::now() - tstart);
      cavg.update(d.count() - cc / 100);
    }
  }

  static const std::string maskToString(long const opmask) {
    stringstream tmp;
    tmp << (opmask & OP_COPYFROM ? "r" : " ") 
        << (opmask & OP_COPYTO   ? "w" : " ");
    return tmp.str();
  }

  Tapasco& tapasco;
};

#endif /* INTERRUPT_LATENCY_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
