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
#ifndef __INTERRUPT_LATENCY_HPP__
#define __INTERRUPT_LATENCY_HPP__

#include <atomic>
#include <thread>
#include <future>
#include <vector>
#include <sstream>
#include <chrono>
#include <cmath>
#include <unistd.h>
#include <ncurses.h>
#include <tpc_api.hpp>

using namespace std;
using namespace std::chrono;
using namespace tpc;

/**
 * Measures interrupt latency added by software layers in TPC.
 **/
class InterruptLatency {
public:
  static tpc_func_id_t const COUNTER_ID = 14;

  InterruptLatency(ThreadPoolComposer& tpc) : tpc(tpc) {
    if (tpc.func_instance_count(COUNTER_ID) == 0)
      throw "need at least one instance of 'Counter' (14) in bitstream";
  }
  virtual ~InterruptLatency() {}

  static constexpr long OP_ALLOCFREE = 0;
  static constexpr long OP_COPYFROM  = 1;
  static constexpr long OP_COPYTO    = 2;

  double operator()(size_t const runtime_usecs) {
    CumulativeAverage<double> cavg { 0 };
    uint32_t clock_cycles = runtime_usecs * 100; // assuming 100Mhz clock
    bool stop = false;
    initscr(); noecho(); curs_set(0); timeout(0);
    int x, y;
    getyx(stdscr, y, x);
    future<void> f = async(launch::async, [&]() { trigger(stop, clock_cycles, cavg); });
    do {
      mvprintw(y, x, "Runtime: %8zu us, Latency: %8.2f", runtime_usecs, cavg());
      refresh();
      usleep(1000);
    } while (getch() == ERR && (fabs(cavg.delta()) > 0.01 || cavg.size() < 10000));
    stop = true;
    f.get();
    move(y+1, 0);
    endwin();
    return cavg();
  }

private:
  void trigger(volatile bool& stop, uint32_t const clock_cycles, CumulativeAverage<double>& cavg) {
    tpc_res_t res;
    while (! stop) {
      auto tstart = high_resolution_clock::now();
      // if 0, use 1us - 100ms interval (clock period is 10ns)
      uint32_t cc = clock_cycles > 0 ? clock_cycles : (rand() % (10000000 - 100) + 100);
      if ((res = tpc.launch_no_return(COUNTER_ID, cc)) != TPC_SUCCESS)
        throw ThreadPoolComposer::tpc_error(res);
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

  ThreadPoolComposer& tpc;
};

#endif /* __INTERRUPT_LATENCY_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
