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
 *  @file	Screen.hpp
 *  @brief	Base class of screens in tapasco-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef SCREEN_HPP__
#define SCREEN_HPP__

#include <functional>
#include <ncurses.h>
#include <unistd.h>

class Screen {
public:
  Screen() {
    getmaxyx(stdscr, rows, cols);
    clear();
  }
  virtual ~Screen() {}
  virtual void show() {
    int choice = ERR;
    do {
      update();
      render();
      refresh();
      choice = perform(getch());
    } while (choice == ERR);
  }

protected:
  virtual void render() = 0;
  virtual void update() = 0;
  virtual int perform(const int choice) {
    if (choice == ERR)
      delay();
    return choice;
  }
  virtual void delay() { usleep(delay_us); }

  /** Toggle to reversed, print, untoggle. **/
  void print_reversed(std::function<void()> fn) {
    attron(A_REVERSE);
    fn();
    attroff(A_REVERSE);
  }

  int rows;
  int cols;
  unsigned long delay_us{500};
};

#endif /* SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
