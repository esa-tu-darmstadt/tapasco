/**
 *  @file	TransferSpeed.hpp
 *  @brief	Measures the transfer speed via TPC for a given chunk size.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef __TRANSFER_SPEED_HPP__
#define __TRANSFER_SPEED_HPP__

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

/** Measurement class that can measure TPC memory transfer speeds. **/
class TransferSpeed {
public:
  TransferSpeed(ThreadPoolComposer& tpc) : tpc(tpc) {}
  virtual ~TransferSpeed() {}

  static constexpr long OP_ALLOCFREE = 0;
  static constexpr long OP_COPYFROM  = 1;
  static constexpr long OP_COPYTO    = 2;

  double operator()(size_t const chunk_sz, long const opmask = 3) {
    double const cs = chunk_sz / 1024.0;
    string const ms = maskToString(opmask);
    CumulativeAverage<double> cavg { 0 };
    bool stop = false;
    bytes = 0;
    initscr(); noecho(); curs_set(0); timeout(0);
    int x, y;
    getyx(stdscr, y, x);
    auto tstart = high_resolution_clock::now();
    double b = 0.0;
    duration<double> d = high_resolution_clock::now() - tstart;
    future<void> f = async(launch::async, [&]() { transfer(stop, chunk_sz, opmask); });
    do {
      b = bytes.load() / (1024.0 * 1024.0);
      d = high_resolution_clock::now() - tstart;
      mvprintw(y, x, "Chunk size: %8.2f KiB, Mask: %s, Speed: %8.2f MiB/s",
          cs, ms.c_str(), cavg());
      refresh();
      usleep(1000);
    } while (getch() == ERR && (fabs(cavg.update(b / d.count())) > 0.01 || cavg.size() < 10000));
    stop = true;
    f.get();
    move(y+1, 0);
    endwin();
    return cavg();
  }

private:
  void transfer(volatile bool& stop, size_t const chunk_sz, long opmask) {
    tpc_handle_t h;
    uint8_t *data = new uint8_t[chunk_sz];
    for (size_t i = 0; i < chunk_sz; ++i)
      data[i] = rand();

    while (! stop) {
      if (tpc.alloc(h, chunk_sz, TPC_DEVICE_ALLOC_FLAGS_NONE) != TPC_SUCCESS)
        throw "allocation failed";
      if (opmask & OP_COPYTO && tpc.copy_to(data, h, chunk_sz, TPC_DEVICE_COPY_BLOCKING) != TPC_SUCCESS)
        throw "copy_to failed";
      if (opmask & OP_COPYFROM && tpc.copy_from(h, data, chunk_sz, TPC_DEVICE_COPY_BLOCKING) != TPC_SUCCESS)
        throw "copy_from failed";
      if (opmask & OP_COPYFROM)
        bytes += chunk_sz;
      if (opmask & OP_COPYTO)
        bytes += chunk_sz;
      tpc.free(h, TPC_DEVICE_ALLOC_FLAGS_NONE);
    }
    delete data;
  }

  static const std::string maskToString(long const opmask) {
    stringstream tmp;
    tmp << (opmask & OP_COPYFROM ? "r" : " ") 
        << (opmask & OP_COPYTO   ? "w" : " ");
    return tmp.str();
  }

  atomic<uint64_t> bytes { 0 };
  ThreadPoolComposer& tpc;
};

#endif /* __TRANSFER_SPEED_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
