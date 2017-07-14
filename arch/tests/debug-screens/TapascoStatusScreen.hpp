/**
 *  @file	TapascoStatusScreen.hpp
 *  @brief	Kernel map screen for tapasco-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TAPASCO_STATUS_SCREEN_HPP__
#define TAPASCO_STATUS_SCREEN_HPP__

#include <tapasco.hpp>
#include <platform.h>
#include <ctime>
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
    const int col_d = 20;
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
    mvhline(start_r + 34, (cols - 80) / 2, ' ', 80);
    mvhline(start_r + 35, (cols - 80) / 2, ' ', 80);
    mvprintw(start_r + 34, (cols - 80) / 2, "#intc: % 2u vivado: %s tapasco: %s gen_ts: %s",
        intcs, vivado_str, tapasco_str, gen_ts_str);
    mvprintw(start_r + 35, (cols - 80) / 2, "host clk: %3d MHz mem clk: %3d MHz design clk: %3d MHz, caps0: 0x%08x",
        host_clk, mem_clk, design_clk, caps0);
    attroff(A_REVERSE);
    mvprintw(start_r + 36, (cols - text_press_key.length()) / 2, text_press_key.c_str());
  }

  virtual void update() {
    const platform::platform_ctl_addr_t status =
        platform::platform_address_get_special_base(platform::PLATFORM_SPECIAL_CTL_STATUS);
    // read ids
    for (int s = 0; s < 128; ++s) {
      if (platform::platform_read_ctl(status + 0x100 + s * 0x10, 4, &id[s],
          platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
        id[s] = 0xDEADBEEF;
    }
    // read number intcs
    if (platform::platform_read_ctl(status + 0x04, 4, &intcs,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      intcs = 0;
    // read caps bitfield
    if (platform::platform_read_ctl(status + 0x08, 4, &caps0,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      caps0 = 0;
    else
      caps0 = caps0 == 0x13371337 ? 0 : caps0;
    // read vivado version
    if (platform::platform_read_ctl(status + 0x10, 4, &vivado,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      vivado = 0;
    if (vivado) {
      snprintf(vivado_str, sizeof(vivado_str), "%4d.%1d", vivado >> 16, vivado & 0xFFFF);
    }
    // read tapasco version
    if (platform::platform_read_ctl(status + 0x14, 4, &tapasco,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      tapasco = 0;
    if (tapasco) {
      snprintf(tapasco_str, sizeof(tapasco_str), "%4d.%1d", tapasco >> 16, tapasco & 0xFFFF);
    }
    // read generation timestamp
    if (platform::platform_read_ctl(status + 0x18, 4, &gen_ts,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      gen_ts = 0;
    if (gen_ts) {
      struct tm ts = *localtime(static_cast<const time_t *>(&gen_ts));
      strftime(gen_ts_str, sizeof(gen_ts_str), "%a %Y-%m-%d %H:%M:%S %Z", &ts);
    }
    // read host clk
    if (platform::platform_read_ctl(status + 0x1c, 4, &host_clk,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      host_clk = 0;
    // read mem clk
    if (platform::platform_read_ctl(status + 0x20, 4, &mem_clk,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      mem_clk = 0;
    // read design clk
    if (platform::platform_read_ctl(status + 0x24, 4, &design_clk,
        platform::PLATFORM_CTL_FLAGS_NONE) != platform::PLATFORM_SUCCESS)
      design_clk = 0;
  }

  virtual int perform(const int choice) {
    if (choice == ERR) delay();
    return choice;
  }

private:
  uint32_t id[128];
  uint32_t intcs;
  uint32_t caps0;
  uint32_t vivado;
  char     vivado_str[16];
  uint32_t tapasco;
  char     tapasco_str[16];
  long     gen_ts;
  char     gen_ts_str[64];
  uint32_t host_clk;
  uint32_t mem_clk;
  uint32_t design_clk;
  const string text_press_key { "--- press any key to exit ---" };
};

#endif /* TAPASCO_STATUS_SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
