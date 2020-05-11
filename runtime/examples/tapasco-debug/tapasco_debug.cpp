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

#include "debug-screens/TapascoDebugMenu.hpp"
#include <iostream>

extern "C" {
void tapasco_logging_deinit(void);
void platform_logging_deinit(void);
}

static void init_ncurses() {
  initscr();
  noecho();
  cbreak();
  curs_set(0);
  timeout(0);
  start_color();
  init_pair(1, COLOR_WHITE, COLOR_RED);
}

static void exit_ncurses() { endwin(); }

int main(int argc, char *argv[]) {
  srand(time(NULL));

  try {
    init_ncurses();
    TapascoDebugMenu menu;
    menu.show();
    exit_ncurses();
  } catch (int e) {
    exit_ncurses();
    cerr << "Error code: " << e << endl;
  } catch (tapasco::Tapasco::tapasco_error &e) {
    exit_ncurses();
    cerr << "TaPaSCo error: " << e.what() << endl;
  } catch (runtime_error &e) {
    exit_ncurses();
    cerr << "Unknown error occurred." << endl;
    exit(1);
  } catch (...) {
    exit_ncurses();
    cerr << "ERROR" << endl;
    throw;
  }

  tapasco_logging_deinit();
  platform_logging_deinit();
}
