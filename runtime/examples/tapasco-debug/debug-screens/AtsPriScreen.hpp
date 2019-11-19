/**
 *  @file	AtsPriScreen.hpp
 *  @brief	ATS/PRI check screen: Interfaces with ATScheck IP core.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef ATSPRI_SCREEN_HPP__
#define ATSPRI_SCREEN_HPP__

#include <cstring>
#include <tapasco.hpp>
extern "C" {
#include <platform.h>
#include <platform_caps.h>
}
#include "MenuScreen.hpp"
#include "WordManipulator.hpp"

class AtsPriScreen : public MenuScreen {
public:
  AtsPriScreen(Tapasco *tapasco)
      : MenuScreen("ATS/PRI direct interface", vector<string>()), _w(0), _b(31),
        _maxlen(0), tapasco(*tapasco) {
    delay_us = 250; // update delay
    // require ATS/PRI
    if (tapasco->has_capability(PLATFORM_CAP0_ATSPRI) != TAPASCO_SUCCESS ||
        tapasco->has_capability(PLATFORM_CAP0_ATSCHECK) != TAPASCO_SUCCESS)
      throw "need both ATS/PRI and ATScheck capabilities!";
    // get ATScheck base address
    platform_address_get_component_base(tapasco->platform_device(),
                                        PLATFORM_COMPONENT_ATSPRI, &atspri);
    // intialize word manipulators
    for (int i = 0; i < ATS_REGC; ++i)
      _word[i].reset(new WordManipulator(0));
    _newp.reset(new WordManipulator(0));
    _newp->set_description("New package");
    _sendp.reset(new WordManipulator(0));
    _sendp->set_description("Send package");
    _write_status.reset(new WordManipulator(0));
    _write_status->set_description("Write status");
    _read_status.reset(new WordManipulator(0));
    _read_status->set_description("Read status");
    _inv_counter.reset(new WordManipulator(0));
    _inv_counter->set_description("Invalidate Packages");
    _inc_pkg_counter.reset(new WordManipulator(0));
    _inc_pkg_counter->set_description("Total Incoming");
    // compute max length of a word manipulator render
    for (int i = 0; i < ATS_REGC; ++i)
      _maxlen = _word[i]->length() > _maxlen ? _word[i]->length() : _maxlen;
    if (_newp->length() > _maxlen)
      _maxlen = _newp->length();
    if (_sendp->length() > _maxlen)
      _maxlen = _sendp->length();
    if (_write_status->length() > _maxlen)
      _maxlen = _write_status->length();
    if (_read_status->length() > _maxlen)
      _maxlen = _read_status->length();
  }

  virtual ~AtsPriScreen() {}

protected:
  virtual void render() {
    const int h = (rows - 3) / ATS_REGC;
    int start_row = (rows - 3 - h * ATS_REGC) / 2;
    int start_col = (cols - _maxlen) / 2;
    // render first block: input request words
    for (int i = 0; i < ATS_REGC / 2; ++i)
      _word[i]->render(start_col, start_row + i, i == _w ? _b : -1);
    // render second block: output response words
    for (int i = ATS_REGC / 2; i < ATS_REGC; ++i)
      print_reversed([&]() {
        _word[i]->render(start_col, start_row + 1 + i, i == _w ? _b : -1);
      });

    // top line
    const char tmp[] = "wasd: move bit cursor  t: toggle bit  o: send  p: "
                       "request new package  q: quit";
    // render additional stuff
    print_reversed([&]() { mvprintw(0, (cols - strlen(tmp)) / 2, tmp); });
    print_reversed(
        [&]() { _newp->render(start_col, start_row + ATS_REGC + 2); });
    print_reversed(
        [&]() { _sendp->render(start_col, start_row + ATS_REGC + 3); });
    print_reversed(
        [&]() { _write_status->render(start_col, start_row + ATS_REGC + 4); });
    print_reversed(
        [&]() { _read_status->render(start_col, start_row + ATS_REGC + 5); });
    print_reversed(
        [&]() { _inv_counter->render(start_col, start_row + ATS_REGC + 6); });
    print_reversed([&]() {
      _inc_pkg_counter->render(start_col, start_row + ATS_REGC + 7);
    });
  }

  virtual int perform(const int choice) {
    bool arrowKey = false;
    if (choice == KEY_UP || static_cast<char>(choice) == 'w') {
      _w = _w == 0 ? 7 : _w - 1;
      arrowKey = true;
    }
    if (choice == KEY_DOWN || static_cast<char>(choice) == 's') {
      _w = _w == 7 ? 0 : _w + 1;
      arrowKey = true;
    }
    if (choice == KEY_RIGHT || static_cast<char>(choice) == 'd') {
      _b = _b == 0 ? 31 : _b - 1;
      arrowKey = true;
    }
    if (choice == KEY_LEFT || static_cast<char>(choice) == 'a') {
      _b = _b == 31 ? 0 : _b + 1;
      arrowKey = true;
    }
    if (arrowKey)
      return ERR;

    if (static_cast<char>(choice) == 't')
      return toggle_bit();
    if (static_cast<char>(choice) == 'o')
      return send();
    if (static_cast<char>(choice) == 'p')
      return request();
    if (static_cast<char>(choice) == 'r')
      return reset();
    if (choice == ERR)
      delay();
    if (static_cast<char>(choice) == 'q')
      return 0;
    return ERR;
  }

  virtual void update() {
    // update new package register
    updateWord(*_newp, 16);
    // update send package register
    updateWord(*_sendp, 17);
    // update read status register
    updateWord(*_read_status, 19);
    // update write status register
    updateWord(*_write_status, 18);
    // update invalid package counter
    updateWord(*_inv_counter, 20);
    // update incoming package counter
    updateWord(*_inc_pkg_counter, 21);
    // update package in and out registers
    for (int i = 0; i < ATS_REGC; ++i)
      updateWord(*_word[i], i);
  }

private:
  static constexpr int ATS_REGC{16};
  int _w, _b;
  std::unique_ptr<WordManipulator> _word[ATS_REGC];
  std::unique_ptr<WordManipulator> _newp;
  std::unique_ptr<WordManipulator> _sendp;
  std::unique_ptr<WordManipulator> _write_status;
  std::unique_ptr<WordManipulator> _read_status;
  std::unique_ptr<WordManipulator> _inv_counter;
  std::unique_ptr<WordManipulator> _inc_pkg_counter;
  size_t _maxlen;
  platform_ctl_addr_t atspri;
  Tapasco &tapasco;

  int toggle_bit() {
    _word[_w]->tgl(_b);
    platform_ctl_addr_t h = atspri;
    auto v = _word[_w]->value();
    if (platform_write_ctl(tapasco.platform_device(), h + _w * 0x4, sizeof(v),
                           &v, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
      _word[_w + 8]->error_on();
    }
    return ERR;
  }

  int send() {
    uint32_t v{1};
    platform_ctl_addr_t h = atspri;
    if (platform_write_ctl(tapasco.platform_device(), h + 0x4 * 17, sizeof(v),
                           &v, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
      return 0;
    }
    return ERR;
  }

  int request() {
    uint32_t v{0};
    platform_ctl_addr_t h = atspri;
    if (platform_write_ctl(tapasco.platform_device(), h + 0x4 * 16, sizeof(v),
                           &v, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
      return 0;
    }
    return ERR;
  }

  int reset() {
    platform_ctl_addr_t h = atspri;
    uint32_t v[] = {
        0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    };
    for (int i = 0; i < ATS_REGC / 2; ++i) {
      if (platform_write_ctl(tapasco.platform_device(), h + i * 0x4,
                             sizeof(v[i]), &v[i],
                             PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
        throw "could not write register";
      }
    }
    return ERR;
  }

  void updateWord(WordManipulator &w, size_t reg_idx) {
    uint32_t d{0};
    if (platform_read_ctl(tapasco.platform_device(), atspri + 0x4 * reg_idx,
                          sizeof(d), &d,
                          PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
      w.error_on();
    } else {
      w.set(d);
      w.error_off();
    }
  }
};

#endif /* ATSPRI_SCREEN_HPP__*/
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
