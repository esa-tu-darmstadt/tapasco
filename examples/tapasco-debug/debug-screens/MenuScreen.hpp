/**
 *  @file	MenuScreen.hpp
 *  @brief	Base class for menu screens in tapasco-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef MENU_SCREEN_HPP__
#define MENU_SCREEN_HPP__

#include <vector>
#include "Screen.hpp"

using namespace std;

class MenuScreen: public Screen {
public:
  MenuScreen(const string& title, const vector<string>& options): options(options), title(title) {}
  virtual ~MenuScreen() {}
protected:
  virtual void render() {
    size_t max_len = 0;
    for (auto const &opt : options)
      max_len = max_len > opt.length() ? max_len : opt.length();
    const int start_row = (rows - options.size() - 4) / 2;
    const int start_col = (cols - max_len - 4) / 2;
    int r = start_row;
    int c = start_col;
    int k = 0;
    mvprintw(r++, (cols - title.length()) / 2, title.c_str());
    r++;
    for (auto const& opt : options)
      mvprintw(r++, c, "(%c) %s", text_keys[k++], opt.c_str());
    r++;
    mvprintw(r++, (cols - text_press_key.length()) / 2, text_press_key.c_str());
  }

  virtual void update() {}

  virtual int perform(const int choice) {
    size_t cidx = choiceToIndex(choice);
    if (cidx >= options.size()) {
      delay();
      return ERR;
    }
    return choice;
  }

  inline virtual size_t choiceToIndex(const int choice) {
    return keys().find(static_cast<char>(choice));
  }

  virtual const string& keys() { return text_keys; }

  MenuScreen() {}
  MenuScreen(MenuScreen& other) {}
  vector<string> options;
  const string title;
  const string text_press_key { "--- Press key to select ---" };
  const string text_keys { "1234567890abcdefghijklmnopqrstuvwxyz" };
};

#endif /* MENU_SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
