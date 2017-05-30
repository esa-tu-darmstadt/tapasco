/**
 *  @file	InterruptStressTestScreen.hpp
 *  @brief	Interrupt stress test screen for tapasco-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef INTERRUPT_STRESS_TEST_SCREEN_HPP__
#define INTERRUPT_STRESS_TEST_SCREEN_HPP__

#include <stack>
#include <tapasco.hpp>
#include "MenuScreen.hpp"

using namespace std;
using namespace tapasco;

class InterruptStressTestScreen : public MenuScreen {
public:
  InterruptStressTestScreen(Tapasco *tapasco) : MenuScreen("Interrupt stress test", vector<string>()), tapasco(tapasco) {
    delay_us = 250000;
    check_bitstream();
  }
  virtual ~InterruptStressTestScreen() {
    while (threads.size() > 0) pop();
  }

  static constexpr tapasco_func_id_t COUNTER_ID { 14 };

protected:
  virtual void render() {
    const int col_d = 18;
    const int row_d = 3;
    int cw = cols / col_d;
    int start_c = (cols - cw * col_d) / 2;
    int start_r = 2;
    const string t = "Interrupt Stress Test using 'counter' instances";

    mvprintw(0, (cols - t.length()) / 2, t.c_str());
    int col = 0; int row = 0;
    for (int id = 0; id < 128; ++id) {
      if (! avail[id]) continue;
      attron(A_REVERSE);
      mvprintw(start_r + row * row_d, start_c + (col + 1) * col_d,
          "%03d:", id);
      attroff(A_REVERSE);
      mvprintw(start_r + row * row_d, start_c + (col + 1) * col_d + 4,
          " 0x%08x", id, cycles[id]);
      mvprintw(start_r + row * row_d + 1, start_c + (col + 1) * col_d,
          "     0x%08x", retval[id]);
      mvprintw(start_r + row * row_d + 2, start_c + (col + 1) * col_d,
          "     0x%08x", intrdy[id]);
      ++col;
      if (col + 1 >= cw) {
        col = 0;
	++row;
      }
    }
    attron(A_REVERSE);
    int r = 0;
    mvprintw(r++, 2,   "Threads: %8u", threads.size());
    for (uint32_t *c : counters)
      mvprintw(r++, 2, "Jobs   : %8u", *c);
    attroff(A_REVERSE);
  }

  virtual int perform(const int choice) {
    if (static_cast<char>(choice) == '+') { push(); return ERR; }
    if (static_cast<char>(choice) == '-') { pop(); return ERR; }
    if (static_cast<char>(choice) == 'j') { for (int i = 8; i > 0; --i) push(); return ERR; }
    if (static_cast<char>(choice) == 'k') { for (int i = 8; i > 0; --i) pop(); return ERR; }
    if (choice == ERR) delay();
    return choice;
  }

  virtual void update() {
    for (int i = 0; i < 128; ++i) {
      if (! avail[i]) continue;
      const platform::platform_ctl_addr_t base = platform::platform_address_get_slot_base(i, 0);
      if (platform::platform_read_ctl(base + 0x20, 4, &cycles[i],
          platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS) {
	cycles[i] = 0xDEADBEEF;
      }
      if (platform::platform_read_ctl(base + 0x10, 4, &retval[i],
          platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS) {
	retval[i] = 0xDEADBEEF;
      }
      if (platform::platform_read_ctl(base + 0x0c, 4, &intrdy[i],
          platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS) {
	intrdy[i] = 0xDEADBEEF;
      }
    }
  }

  void push() {
    counters.push_back(new uint32_t);
    *counters.back() = 0;
    stop.push_back(new bool);
    *stop.back() = false;
    auto f = [](bool *stop, uint32_t *c, Tapasco *tapasco) {
      while (! *stop) {
        (*c)++;
	// up to 50ms delay
	tapasco_res_t r = tapasco->launch_no_return(14, static_cast<uint32_t>(rand() % 5000000));
	//tapasco_res_t r = tapasco->launch_no_return(14, static_cast<uint32_t>(1));
	if (r != TAPASCO_SUCCESS)
	  throw Tapasco::tapasco_error(r);
      }
      return true;
    };
    thread t {f, stop.back(), counters.back(), tapasco};
    threads.push(move(t));
  }

  void pop() {
    if (threads.size() > 0) {
      *stop.back() = true;
      threads.top().join();
      move(threads.top());
      threads.pop();
      delete stop.back();
      stop.pop_back();
      delete counters.back();
      counters.pop_back();
      clear();
    }
  }
private:
  bool check_bitstream() {
    uint32_t id { 0 }, cnt { 0 };
    const platform::platform_ctl_addr_t status =
        platform::platform_address_get_special_base(platform::PLATFORM_SPECIAL_CTL_STATUS);
    for (int s = 0; s < 128; ++s) {
      if (platform::platform_read_ctl(status + 0x100 + s * 0x10, 4, &id,
          platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
        avail[s] = false;
      else {
        avail[s] = id == COUNTER_ID;
	if (avail[s]) ++cnt;
      }
    }
    return cnt > 0;
  }

  stack<thread> threads;
  vector<uint32_t *> counters;
  vector<bool *> stop;
  bool     avail [128];
  uint32_t cycles[128];
  uint32_t retval[128];
  uint32_t intrdy[128];
  Tapasco *tapasco;
};

#endif /* INTERRUPT_STRESS_TEST_SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
