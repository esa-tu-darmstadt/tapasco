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
    exit_ncurses();
    cerr << "Error code: " << e << endl;
  } catch (tapasco::Tapasco::tapasco_error e) {
    exit_ncurses();
    cerr << e.what() << endl;
  } catch (runtime_error e) {
    exit_ncurses();
    cerr << "Unknown error occurred." << endl;
    exit(1);
  } catch (...) {
    exit_ncurses();
    cerr << "ERROR" << endl;
    throw;
  }
}
