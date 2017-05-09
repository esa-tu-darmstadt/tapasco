/**
 *  @file	tapasco_debug.cpp
 *  @brief	A TPC Debugging application.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/

#include <iostream>
#include "debug-screens/TapascoDebugMenu.hpp"

static void init_ncurses()
{
  initscr();
  noecho();
  cbreak();
  curs_set(0);
  timeout(0);
  start_color();
  init_pair(1, COLOR_WHITE, COLOR_RED);
}

static void exit_ncurses()
{
  endwin();
}

int main(int argc, char *argv[])
{
  srand(time(NULL));

  try {
    init_ncurses();
    TapascoDebugMenu menu;
    menu.show();
    exit_ncurses();
  } catch (int e) {
    cerr << "Error code: " << e << endl;
  }
}
