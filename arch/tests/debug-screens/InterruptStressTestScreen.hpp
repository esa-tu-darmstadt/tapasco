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

  static constexpr tapasco_kernel_id_t COUNTER_ID { 14 };

protected:
  virtual void render() {
    const int height = 36;
    const int start_r = (rows - 36) / 2;
    const int col_w = 17;
    const int num_cols = threads.size() / 32 + 1;
    const int start_c = (cols - num_cols * col_w) / 2;
    const string title = " Interrupt Stress Test using 'counter' instances ";
    const string bottom = " +/-: add/remove thread  j/k: add/remove 8 threads ";
    char tmp[128] = "";

    erase();

    print_reversed([&](){mvprintw(start_r, (cols - title.length()) / 2, title.c_str());});
    print_reversed([&](){mvprintw(start_r + height, (cols - bottom.length()) / 2, bottom.c_str());});

    for (size_t t = 0; t < threads.size(); ++t) {
      snprintf(tmp, 128, "%03zu:", t);
      print_reversed([&](){mvprintw(start_r + 2 + t % 32, start_c + t / 32 * col_w, tmp);});
      snprintf(tmp, 128, "%11u", *(counters[t]));
      mvprintw(start_r + 2 + t % 32, start_c + t / 32 * col_w + 5, tmp);
    }
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
      platform_ctl_addr_t base;
      platform_address_get_slot_base(tapasco->platform_device(), i, &base);
      if (platform_read_ctl(tapasco->platform_device(), base + 0x20, 4, &cycles[i],
          PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
	cycles[i] = 0xDEADBEEF;
      }
      if (platform_read_ctl(tapasco->platform_device(), base + 0x10, 4, &retval[i],
          PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
	retval[i] = 0xDEADBEEF;
      }
      if (platform_read_ctl(tapasco->platform_device(), base + 0x0c, 4, &intrdy[i],
          PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
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
    platform_info_t info;
    platform_res_t r = tapasco->info(&info);
    if (r != PLATFORM_SUCCESS)
      throw new Tapasco::tapasco_error(TAPASCO_ERR_PLATFORM_FAILURE);
    for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
      if (info.composition.kernel[s] == COUNTER_ID) return true;
    }
    return false;
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
