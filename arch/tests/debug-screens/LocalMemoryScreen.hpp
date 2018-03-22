/**
 *  @file	LocalMemoryScreen.hpp
 *  @brief	Interface to local memories: read/write pe-local memory.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef LOCAL_MEMORY_SCREEN_HPP__
#define LOCAL_MEMORY_SCREEN_HPP__

#include <iostream>
#include <fstream>
#include <sstream>
#include <tapasco.hpp>
#include <cmath>
#include "MenuScreen.hpp"
extern "C" {
  #include <errno.h>
  #include <tapasco_memory.h>
}

typedef struct {
  platform_slot_id_t slot;
  platform_slot_id_t pe;
  size_t size;
  size_t free;
  bool is_selected;
} memory_t;

class LocalMemoryScreen : public MenuScreen {
public:
  LocalMemoryScreen(Tapasco& tapasco) : MenuScreen("PE-local memory monitor", vector<string>()), tapasco(tapasco) {
    tapasco.info(&info);
    keypad(stdscr, TRUE);
    init_memories();
  }

  virtual ~LocalMemoryScreen() {}

  static bool has_local_memories(Tapasco& tapasco) {
    if (tapasco.has_capability(PLATFORM_CAP0_PE_LOCAL_MEM)) {
      platform_info_t info;
      tapasco.info(&info);
      for (platform_slot_id_t s = 0; s < TAPASCO_NUM_SLOTS; ++s) {
        if (info.composition.memory[s]) return true;
      }
    }
    return false;
  }

protected:
  void init_memories() {
    platform_slot_id_t curr_pe = 0;
    for (platform_slot_id_t s = 0; s < TAPASCO_NUM_SLOTS; ++s) {
      if (info.composition.memory[s]) {
        unique_ptr<memory_t> m(new memory_t());
        *m = {
          .slot = s,
          .pe   = curr_pe,
          .size = info.composition.memory[s],
          .free = info.composition.memory[s],
	  .is_selected = mem.size() == 0,
        };
        mem.push_back(move(m));
      }
    }
    curr_sel = 0;
  }

  virtual void render() {
    const string title  { " Local Memories " };
    const string bottom { " up/down: select slot right/left: save/load data " };
    int row = (rows - (mem.size() + 4)) / 2;
    print_reversed([&](){mvprintw(row, (cols - title.length()) / 2, title.c_str());});
    row += 2;
    for (auto& m : mem)
      render_mem(row++, *m);
    ++row;
    print_reversed([&](){mvprintw(row, (cols - bottom.length()) / 2, bottom.c_str());});
  }

  virtual int perform(const int choice) {
    if (choice == KEY_UP) return prev_slot();
    if (choice == KEY_DOWN) return next_slot();
    if (choice == KEY_LEFT) return loadsave(true);
    if (choice == KEY_RIGHT) return loadsave(false);
    if (choice == ERR) delay();
    if (choice == 'q') return choice;
    return ERR;
  }

  virtual void update() {
    tapasco_local_mem_t *lm = tapasco_device_local_mem(tapasco.device());
    for (auto& m : mem) {
      m->free = tapasco_local_mem_get_free(lm, m->slot);
    }
  }

private:
  int prev_slot() {
    mem[curr_sel]->is_selected = false;
    curr_sel = (curr_sel - 1) % mem.size();
    mem[curr_sel]->is_selected = true;
    return ERR;
  }

  int next_slot() {
    mem[curr_sel]->is_selected = false;
    curr_sel = (curr_sel + 1) % mem.size();
    mem[curr_sel]->is_selected = true;
    return ERR;
  }

  int loadsave(bool const load) {
    static const string q = " Filename:";
    static const string lconf =  "OK to load data to PE-local memory   (y/n)?";
    static const string sconf =  "OK to save data from PE-local memory (y/n)?";
    char tmp[256] = "";
    int c = ERR;
    clear();
    nocbreak();
    timeout(-1);
    attron(A_REVERSE);
    mvprintw(rows / 2 - 1, (cols - lconf.length()) / 2, q.c_str());
    move(rows / 2 - 1, (cols - lconf.length()) / 2 + q.length() + 3);
    attroff(A_REVERSE);
    echo();
    getstr(tmp);
    noecho();
    cbreak();
    attron(A_REVERSE);
    mvprintw(rows / 2 + 1, (cols - lconf.length()) / 2, load ? lconf.c_str() : sconf.c_str());
    attroff(A_REVERSE);
    char chr = static_cast<char>(c);
    do {
      c = getch();
      chr = static_cast<char>(c);
      if (chr == 'y') return load ? load_memory(*mem[curr_sel], tmp) : save_memory(*mem[curr_sel], tmp);
    } while (c == ERR);
    cbreak();
    noecho();
    clear();
    return ERR;
  }

  int save_memory(memory_t const& m, string const& fn) {
    static const string success = "OK, data written to file.";
    static const string copying = " ... copying ... ";
    clear();
    mvprintw(rows / 2, (cols - copying.length()) / 2, copying.c_str());
    uint32_t *data = new uint32_t[m.size / sizeof(uint32_t)];
    memset((void *)data, 0, m.size);
    tapasco_res_t r = tapasco_device_copy_from_local(tapasco.device(), 0, data, m.size, TAPASCO_DEVICE_COPY_FLAGS_NONE, m.slot);
    if (r != TAPASCO_SUCCESS) throw Tapasco::tapasco_error(r);
    ofstream outf(fn, ios::out | ios::binary);
    if (outf.is_open()) {
      outf.write((const char *)data, m.size);
      outf.close();
      clear();
      mvprintw(rows / 2, (cols - success.length()) / 2, success.c_str());
    } else {
      stringstream ss;
      ss << "I/O error: " << strerror(errno);
      mvprintw(rows / 2, (cols - ss.str().length()) / 2, ss.str().c_str());
    }
    delete data;
    do {} while (getch() == ERR);
    clear();
    return ERR;
  }

  int load_memory(memory_t const& m, string const& fn) {
    static const string success = "OK, file written to memory.";
    static const string copying = " ... copying ... ";
    clear();
    mvprintw(rows / 2, (cols - copying.length()) / 2, copying.c_str());
    uint32_t *data = new uint32_t[m.size / sizeof(uint32_t)];
    memset((void *)data, 0, m.size);

    ifstream inf(fn, ios::in | ios::binary);
    if (inf) {
      inf.read((char *)data, m.size);
      inf.close();
      clear();
      mvprintw(rows / 2, (cols - copying.length()) / 2, copying.c_str());
      tapasco_res_t r = tapasco_device_copy_to_local(tapasco.device(), data, 0, m.size, TAPASCO_DEVICE_COPY_FLAGS_NONE, m.slot);
      delete data;
      clear();
      if (r != TAPASCO_SUCCESS) throw Tapasco::tapasco_error(r);
      mvprintw(rows / 2, (cols - success.length()) / 2, success.c_str());
    } else {
      stringstream ss;
      ss << "I/O error: " << strerror(errno);
      mvprintw(rows / 2, (cols - ss.str().length()) / 2, ss.str().c_str());
    }
    do {} while (getch() == ERR);
    clear();
    return ERR;
  }

  void render_mem(int const row, const memory_t& m) {
    char tmp[256] = "";
    int start_c = (cols - 60) / 2;
    snprintf(tmp, 256, "PE #%03d, local mem: %03d:", m.slot, m.pe);
    if (m.is_selected) {
      print_reversed([&](){mvprintw(row, start_c, tmp);});
    } else {
      mvprintw(row, start_c, tmp);
    }
    snprintf(tmp, 256, "%8zu B / %8zu B free", m.free, m.size);
    mvprintw(row, start_c + 20 + 12, tmp);
    memset(tmp, 0, sizeof(tmp));
    size_t s = (size_t)(round(10.f * m.free / m.size));
    memset(tmp, ' ', s);
    print_reversed([&](){mvprintw(row, start_c + 20, tmp);});
  }

  vector<unique_ptr<memory_t> > mem;
  size_t curr_sel;
  platform_info_t info;
  Tapasco &tapasco;
};

#endif /* LOCAL_MEMORY_SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
