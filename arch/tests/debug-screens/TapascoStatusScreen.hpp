/**
 *  @file	TapascoStatusScreen.hpp
 *  @brief	Kernel map screen for tapasco-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef __TAPASCO_STATUS_SCREEN_HPP__
#define __TAPASCO_STATUS_SCREEN_HPP__

#include <tapasco_api.hpp>
#include <platform_api.h>
#include "MenuScreen.hpp"
using namespace tapasco;

class TapascoStatusScreen: public MenuScreen {
public:
  TapascoStatusScreen(Tapasco *tapasco): MenuScreen("", vector<string>()) {
    delay_us = 10000;
  }
  virtual ~TapascoStatusScreen() {}
protected:
  virtual void render() {
    const int col_d = 16; //(cols - 4) / 4;
    int start_c = (cols - 4 * col_d) / 2;
    int start_r = (rows - 6 - 32) / 2;
    const string t = "Current Bitstream Kernel Map (via TPC Status Core)";
    mvprintw(start_r, (cols - t.length()) / 2, t.c_str());
    for (int col = 0; col < 4; ++col) {
      for (int row = 0; row < 32; ++row) {
        attron(A_REVERSE);
	mvprintw(start_r + 2 + row, start_c + col * col_d, "%03d:", col * 32 + row);
	attroff(A_REVERSE);
        if (id[col * 32 + row] > 0 && id[col * 32 + row] != 0xDEADBEEF)
          mvprintw(start_r + 2 + row, start_c + 4 + col * col_d, " 0x%08x", id[col * 32 + row]);
	else
          mvprintw(start_r + 2 + row, start_c + 4 + col * col_d, "           ", col * 32 + row);
      }
    }
    attron(A_REVERSE);
    mvprintw(start_r + 35, (cols - 17) / 2, "#intc: %10u", intcs);
    attroff(A_REVERSE);
    mvprintw(start_r + 37, (cols - text_press_key.length()) / 2, text_press_key.c_str());
  }

  virtual void update() {
    const platform::platform_ctl_addr_t status =
        platform::platform_address_get_special_base(platform::PLATFORM_SPECIAL_CTL_STATUS);
    for (int s = 0; s < 128; ++s) {
      if (platform::platform_read_ctl(status + 0x100 + s * 0x10, 4, &id[s],
          platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
        id[s] = 0xDEADBEEF;
    }
    if (platform::platform_read_ctl(status + 0x04, 4, &intcs,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      intcs = 0;
  }

  virtual int perform(const int choice) {
    if (choice == ERR) delay();
    return choice;
  }

private:
  uint32_t id[128];
  uint32_t intcs;
  const string text_press_key { "--- press any key to exit ---" };
};

#endif /* __TAPASCO_STATUS_SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
