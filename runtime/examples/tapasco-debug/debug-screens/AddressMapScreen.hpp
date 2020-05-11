/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
/**
 *  @file	AddressMapScreen.hpp
 *  @brief	Reads address map from status core and displays base addresses.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef ADDRESS_MAP_SCREEN_HPP__
#define ADDRESS_MAP_SCREEN_HPP__

#include <cstring>
#include <tapasco.hpp>

#include "MenuScreen.hpp"

using namespace tapasco;

static const char *component_names[] = {
    "STATUS", "ATSPRI", "INTC0", "INTC1", "INTC2", "INTC3", "MSIX0",
    "MSIX1",  "MSIX2",  "MSIX3", "DMA0",  "DMA1",  "DMA2",  "DMA3",
};

class AddressMapScreen : public MenuScreen {
public:
  AddressMapScreen(Tapasco &tapasco)
      : MenuScreen("Address Map", vector<string>()), tapasco(tapasco) {
    if (!tapasco.has_capability(PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP))
      throw Tapasco::tapasco_error("need dynamic address map capability!");
  }

  virtual ~AddressMapScreen() {}

protected:
  virtual void render() {
    int const start_row = (rows - 52) / 2;
    int row = start_row > 0 ? start_row : 1;
    const char tmp[] = " Platform Components ";
    print_reversed([&]() { mvprintw(row, (cols - strlen(tmp)) / 2, tmp); });
    row += 2;
    for (int c = PLATFORM_COMPONENT_STATUS; c <= PLATFORM_COMPONENT_DMA3;
         ++c, ++row) {
      render_platform_component(row, component_names[c], info.base.platform[c]);
    }

    const char tmp2[] = " Architecture  Slots ";
    row += 2;
    print_reversed([&]() { mvprintw(row, (cols - strlen(tmp2)) / 2, tmp2); });
    row += 2;
    for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
      render_slot(row, s, info.base.arch[s]);
    }
  }

  virtual int perform(const int choice) {
    if (choice == ERR)
      delay();
    return choice;
  }

  virtual void update() { tapasco.info(&info); }

private:
  void render_platform_component(const int r, const char *name,
                                 platform_ctl_addr_t const b) {
    char tmp[256] = "";
    snprintf(tmp, 256, " %6s:", name);
    attron(A_REVERSE);
    mvprintw(r, (cols - 19) / 2, tmp);
    attroff(A_REVERSE);
    snprintf(tmp, 256, " 0x%08lx", (unsigned long)b);
    mvprintw(r, (cols - 19) / 2 + 8, tmp);
  }

  void render_slot(const int r, platform_slot_id_t const s,
                   platform_ctl_addr_t const b) {
    char tmp[256] = "";
    int const startcol = (cols - 22 * 4) / 2 + (22 * (s / 32));
    int const startrow = r + (s % 32);
    snprintf(tmp, 256, "SLOT #%03d:", s);
    attron(A_REVERSE);
    mvprintw(startrow, startcol, tmp);
    attroff(A_REVERSE);
    snprintf(tmp, 256, " 0x%08lx ", (unsigned long)b);
    mvprintw(startrow, startcol + 10, tmp);
  }

  Tapasco &tapasco;
  platform_info_t info;
};

#endif /* ADDRESS_MAP_SCREEN_HPP__ */
