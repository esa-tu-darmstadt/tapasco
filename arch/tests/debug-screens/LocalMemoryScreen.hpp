/**
 *  @file	LocalMemoryScreen.hpp
 *  @brief	Interface to local memories: read/write pe-local memory.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef LOCAL_MEMORY_SCREEN_HPP__
#define LOCAL_MEMORY_SCREEN_HPP__

#include <tapasco.hpp>
#include "MenuScreen.hpp"

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
        };
        mem.push_back(move(m));
      }
    }
  }

  virtual void render() {
    const string title  { " Local Memories " };
    const string bottom { " uo/down: select slot s/l: save/load memory " };
    int row = (rows - (mem.size() + 4)) / 2;
    print_reversed([&](){mvprintw(row, (cols - title.length()) / 2, title.c_str());});
    row += 2;
    for (auto& m : mem)
      render_mem(row++, *m);
    ++row;
    print_reversed([&](){mvprintw(row, (cols - title.length()) / 2, title.c_str());});
  }

  virtual int perform(const int choice) {
    if (choice == ERR) delay();
    return choice;
  }

  virtual void update() {
    tapasco_local_mem_t *lm = tapasco_device_local_mem(tapasco.device());
    for (auto& m : mem) {
      m->free = tapasco_local_mem_get_free(lm, m->slot);
    }
  }

private:
  void render_mem(int const row, const memory_t& m) {
    char tmp[256] = "";
    int start_c = (cols - 60) / 2;
    snprintf(tmp, 256, "PE #%03d, local mem: %03d:", m.slot, m.pe);
    if (m.is_selected) {
      print_reversed([&](){mvprintw(row, start_c, tmp);});
    } else {
      mvprintw(row, start_c, tmp);
    }
    snprintf(tmp, 256, "%08zu B / %08zu B free", m.free, m.size);
    mvprintw(row, start_c + 20 + 12, tmp);
    memset(tmp, 0, sizeof(tmp));
    memset(tmp, ' ', 10 * m.free / m.size);
    print_reversed([&](){mvprintw(row, start_c + 20, tmp);});
  }

  vector<unique_ptr<memory_t> > mem;
  platform_info_t info;
  Tapasco &tapasco;
};

#endif /* LOCAL_MEMORY_SCREEN_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
