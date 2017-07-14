/**
 *  @file	WordManipulator.hpp
 *  @brief	ATS/PRI check screen: Model of a 32bit register.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef WORDMANIPULATOR_HPP__
#define WORDMANIPULATOR_HPP__

#include <iomanip>
#include <ncurses.h>
#include <stdint.h>
#include <string>
#include <sstream>

/**
 * WordManipulator models a 32bit register with operations on it.
 * It can render itself using ncurses, in a format like this:
 * |00000000|00000000|00000000|00000000| 0x00000000 Description
 **/
class WordManipulator {
public:
  WordManipulator(uint32_t init) : _v(init), _error_on(false), _desc("") {}
  virtual ~WordManipulator() {}
  bool bit(uint8_t bit) const { return (_v & (1 << bit)) > 0; }
  void set(uint8_t bit) { _v |= (1 << bit); }
  void clr(uint8_t bit) { _v &= ~(1 << bit); }
  void tgl(uint8_t bit) { _v ^= (1 << bit); }
  uint32_t value() const { return _v; }
  void set(uint32_t v) { _v = v; }
  void error_on()  { _error_on = true; }
  void error_off() { _error_on = false; }
  void set_description(std::string d) { _desc = d; }
  size_t length() { return 47 + _desc.length(); }

  void render(int x, int y, uint8_t b = -1) {
    std::stringstream formatted;
    for(int i = 0; i < 32; i += 1) {
        if((i % 8) == 0) formatted << '|';
        formatted << bit(31 - i);
    }
    formatted << "| 0x" << std::hex << std::setfill('0') << std::setw(8) << _v;
    formatted << " " << _desc;

    if (_error_on) attron(COLOR_PAIR(1));
    mvprintw(y, x, formatted.str().c_str());
    if (_error_on) attroff(COLOR_PAIR(1));
    if (b >= 0) {
      attron(A_REVERSE);
      mvprintw(y, x + 1 + ((31 - b) / 8) + (31 - b), "%d", bit(b));
      attroff(A_REVERSE);
    }
  }

private:
  uint32_t _v;
  bool _error_on;
  std::string _desc;
};

#endif /* WORDMANIPULATOR_HPP__*/
