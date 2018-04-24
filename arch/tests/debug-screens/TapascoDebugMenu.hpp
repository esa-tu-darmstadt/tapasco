/**
 *  @file	TapascoDebugMenu.hpp
 *  @brief	Main menu of tapasco-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TAPASCO_DEBUG_MENU_HPP__
#define TAPASCO_DEBUG_MENU_HPP__

#include <tapasco.hpp>
#include "MenuScreen.hpp"
#include "TapascoStatusScreen.hpp"
#include "InterruptStressTestScreen.hpp"
#include "MonitorScreen.hpp"
#include "BlueDebugScreen.hpp"
#include "AtsPriScreen.hpp"
#include "AddressMapScreen.hpp"
#include "LocalMemoryScreen.hpp"

extern "C" {
  #include <platform_caps.h>
}

using namespace tapasco;

class TapascoDebugMenu : public MenuScreen {
public:
  TapascoDebugMenu() : MenuScreen("Welcome to the interactive TaPaSCo Debugger", vector<string>()),
      tapasco(true, TAPASCO_MONITOR_ACCESS) {
    bool blue = has_blue_dma();
    options.push_back("Show kernel map of current bitstream");
    screens.push_back(new TapascoStatusScreen(&tapasco));
    if (tapasco.has_capability(PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP)) {
      options.push_back("Show address map of current bitstream");
      screens.push_back(new AddressMapScreen(tapasco));
    }
    options.push_back("Monitor device registers");
    screens.push_back(new MonitorScreen(&tapasco));
    if (LocalMemoryScreen::has_local_memories(tapasco)) {
      options.push_back("Monitor PE-local memories");
      screens.push_back(new LocalMemoryScreen(tapasco));
    }
    options.push_back("Perform interrupt stress test");
    screens.push_back(new InterruptStressTestScreen(&tapasco));
    if (blue) {
      options.push_back("Monitor blue infrastructure");
      screens.push_back(new BlueDebugScreen(&tapasco));
    }
    if (tapasco.has_capability(PLATFORM_CAP0_ATSPRI) && tapasco.has_capability(PLATFORM_CAP0_ATSCHECK)) {
      options.push_back("ATS/PRI direct interface");
      screens.push_back(new AtsPriScreen(&tapasco));
    }
    options.push_back("Exit");
  }
  virtual ~TapascoDebugMenu() {
    for (auto *s : screens)
      delete s;
  }
protected:
  virtual int perform(const int choice) {
    if (choice == ERR) delay();
    else {
      size_t cidx = choiceToIndex(choice);
      if (cidx < screens.size()) {
        clear();
        screens[cidx]->show();
	clear();
	return ERR;
      }
    }
    return choice;
  }

  bool has_blue_dma() {
#if defined(__i386__) || defined (__x86_64__) || defined(__amd64__)
    // x86 platforms might have PCIe devices, so blue monitors are useful regardless of whether BlueDMA is present
    return true;
#else
    platform_info_t info;
    tapasco.info(&info);
    uint32_t v;
    for (int c = PLATFORM_COMPONENT_DMA0; c <= PLATFORM_COMPONENT_DMA3; ++c) {
      if (d->info.base.platform[c]) {
      	uint32_t v = 0;
        platform_read_ctl(p, d->info.base.platform[c] + DMA_ID_REG, sizeof(v), &v, PLATFORM_CTL_FLAGS_NONE);
	if (v == BLUE_DMA_ID) return true;
      }
    }
    return false;
#endif
  }

private:
  static constexpr unsigned long DMA_ID_REG = 0x18UL;
  static constexpr unsigned long BLUE_DMA_ID = 0xE5A0023;
  vector<Screen *> screens;
  Tapasco tapasco;
};

#endif /* TAPASCO_DEBUG_MENU_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
