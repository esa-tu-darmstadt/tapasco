/**
 *  @file	Screen.hpp
 *  @brief	Base class of screens in tpc-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef __SCREEN_HPP__
#define __SCREEN_HPP__

#include <ncurses.h>
#include <unistd.h>

class Screen {
public:
  Screen() { getmaxyx(stdscr, rows, cols); clear(); }
  virtual ~Screen() {}
  virtual void show() {
    int choice = ERR;
    do { update(); render(); refresh(); choice = perform(getch()); }
    while (choice == ERR);
  }
protected:
  virtual void render() = 0;
  virtual void update() = 0;
  virtual int perform(const int choice) { if (choice == ERR) delay(); return choice; }
  virtual void delay() { usleep(delay_us); }

  int rows;
  int cols;
  unsigned long delay_us { 500 };
};

#endif  /* __SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
