/**
 *  @file TransferSpeed.hpp
 *  @brief  Measures the transfer speed via TPC for a given chunk size.
 *  @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TRANSFER_SPEED_HPP__
#define TRANSFER_SPEED_HPP__

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

/** Measurement class that can measure TPC memory transfer speeds. **/
class TransferSpeed {
public:
  TransferSpeed(Tapasco& tapasco) : tapasco(tapasco) {}
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
    int x, y;
    getyx(stdscr, y, x);
    auto tstart = high_resolution_clock::now();
    double b = 0.0;
    duration<double> d = high_resolution_clock::now() - tstart;
    future<void> f = async(launch::async, [&]() { transfer(stop, chunk_sz, opmask); });
    auto c = getch();
    do {
      mvprintw(y, x, "Chunk size: %8.2f KiB, Mask: %s, Speed: %8.2f MiB/s",
               cs, ms.c_str(), cavg());
      refresh();
      usleep(1000000);
      b = bytes.load() / (1024.0 * 1024.0);
      d = high_resolution_clock::now() - tstart;
      // exit gracefully on ctrl+c
      c = getch();
      if (c == 3) { endwin(); exit(3); }
    } while (c == ERR && (fabs(cavg.update(b / d.count())) > 0.1 || cavg.size() < 30));
    stop = true;
    f.get();

    mvprintw(y, x, "Chunk size: %8.2f KiB, Mask: %s, Speed: %8.2f MiB/s",
             cs, ms.c_str(), cavg());
    refresh();
    move(y + 1, 0);
    return cavg();
  }

private:

  tapasco_res_t do_read(volatile bool& stop, size_t const chunk_sz, long opmask, uint8_t *data) {
    if (!(opmask & OP_COPYFROM))
      return TAPASCO_SUCCESS;
    while (!stop) {
      tapasco_handle_t h;
      if (tapasco.alloc(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE) != TAPASCO_SUCCESS)
        return TAPASCO_FAILURE;
      if (tapasco.copy_from(h, data, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING) != TAPASCO_SUCCESS) {
        tapasco.free(h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
        return TAPASCO_FAILURE;
      }
      tapasco.free(h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
      bytes += chunk_sz;
    }
    return TAPASCO_SUCCESS;
  }

  tapasco_res_t do_write(volatile bool& stop, size_t const chunk_sz, long opmask, uint8_t *data) {
    if (!(opmask & OP_COPYTO))
      return TAPASCO_SUCCESS;
    tapasco_handle_t h;
    while (! stop) {
      if (tapasco.alloc(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE) != TAPASCO_SUCCESS)
        return TAPASCO_FAILURE;
      if (tapasco.copy_to(data, h, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING) != TAPASCO_SUCCESS) {
        tapasco.free(h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
        return TAPASCO_FAILURE;
      }
      tapasco.free(h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
      bytes += chunk_sz;
    }
    return TAPASCO_SUCCESS;
  }

  void transfer(volatile bool& stop, size_t const chunk_sz, long opmask) {

    uint8_t *data_read = new (std::nothrow) uint8_t[chunk_sz];
    if (! data_read) return;
    for (size_t i = 0; i < chunk_sz; ++i)
      data_read[i] = rand();

    uint8_t *data_write = new (std::nothrow) uint8_t[chunk_sz];
    if (! data_write) return;
    for (size_t i = 0; i < chunk_sz; ++i)
      data_write[i] = rand();

    std::thread readthread(&TransferSpeed::do_read, this, std::ref(stop), chunk_sz, opmask, data_read);
    std::thread writethread(&TransferSpeed::do_write, this, std::ref(stop), chunk_sz, opmask, data_write);

    readthread.join();
    writethread.join();

    delete[] data_read;
    delete[] data_write;
  }

  static const std::string maskToString(long const opmask) {
    stringstream tmp;
    tmp << (opmask & OP_COPYFROM ? "r" : " ")
        << (opmask & OP_COPYTO   ? "w" : " ");
    return tmp.str();
  }

  atomic<uint64_t> bytes { 0 };
  Tapasco& tapasco;
};

#endif /* TRANSFER_SPEED_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */