/**
 *  @file TransferSpeed.hpp
 *  @brief  Measures the transfer speed via TPC for a given chunk size.
 *  @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TRANSFER_SPEED_HPP__
#define TRANSFER_SPEED_HPP__

#include <atomic>
#include <memory>
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

/** Measurement class that can measure TaPaSCo memory transfer speeds. **/
class TransferSpeed {
public:
  TransferSpeed(Tapasco& tapasco) : tapasco(tapasco) {}
  virtual ~TransferSpeed() {}

  static constexpr long OP_ALLOCFREE = 0;
  static constexpr long OP_COPYFROM  = 1;
  static constexpr long OP_COPYTO    = 2;

  double operator()(size_t const chunk_sz, long const opmask = 3) {
    CumulativeAverage<double> cavg 	{ 0 };
    atomic<bool> stop 			{ false };
    double const cs 			{ chunk_sz / 1024.0 };
    string const ms 			{ maskToString(opmask) };
    double b 				{ 0.0 };
    int x, y;
    
    bytes = 0;
    getyx(stdscr, y, x);

    auto tstart 			{ high_resolution_clock::now() };
    duration<double> d 			{ high_resolution_clock::now() - tstart };
    future<void> f 			{ async(launch::async, [&]() { transfer(stop, chunk_sz, opmask); }) };
    auto c 				{ getch() };
    do {
      mvprintw(y, x, "Chunk size: %8.2f KiB, Mask: %s, Speed: %8.2f MiB/s",
               cs, ms.c_str(), cavg());
      refresh();
      usleep(1000000);
      b = bytes.load() / (1024.0 * 1024.0);
      d = high_resolution_clock::now() - tstart;
      // exit "gracefully" on ctrl+c
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

  tapasco_res_t do_read(volatile atomic<bool>& stop, size_t const chunk_sz, long opmask, uint8_t *data) {
    if (!(opmask & OP_COPYFROM))
      return TAPASCO_SUCCESS;
    tapasco_handle_t h;
    tapasco_res_t r { tapasco.alloc(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE) };
    if (r != TAPASCO_SUCCESS) 	{ return r; }
    while (! stop.load()) {
      r = tapasco.copy_from(h, data, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
      if (r != TAPASCO_SUCCESS) { stop  = true; }
      else 			{ bytes += chunk_sz; }
    }
    tapasco.free(h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
    return r;
  }

  tapasco_res_t do_write(volatile atomic<bool>& stop, size_t const chunk_sz, long opmask, uint8_t *data) {
    if (!(opmask & OP_COPYTO))
      return TAPASCO_SUCCESS;
    tapasco_handle_t h;
    tapasco_res_t r { tapasco.alloc(h, chunk_sz, TAPASCO_DEVICE_ALLOC_FLAGS_NONE) };
    if (r != TAPASCO_SUCCESS) 	{ return r; }
    while (! stop.load()) {
      r = tapasco.copy_to(data, h, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
      if (r != TAPASCO_SUCCESS) { stop  = true; }
      else                      { bytes += chunk_sz; }
    }
    tapasco.free(h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
    return r;
  }

  void transfer(volatile atomic<bool>& stop, size_t const chunk_sz, long opmask) {
    std::vector<uint8_t> data_read(chunk_sz);
    for (auto& i : data_read)
      i = rand();

    std::vector<uint8_t> data_write(chunk_sz);
    for (auto& i : data_write)
      i = rand();

    std::thread readthread(&TransferSpeed::do_read, this, std::ref(stop), chunk_sz, opmask, data_read.data());
    std::thread writethread(&TransferSpeed::do_write, this, std::ref(stop), chunk_sz, opmask, data_write.data());

    readthread.join();
    writethread.join();
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
