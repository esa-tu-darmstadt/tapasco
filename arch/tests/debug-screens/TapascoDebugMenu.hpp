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

using namespace tapasco;

class TapascoDebugMenu : public MenuScreen {
public:
  TapascoDebugMenu() : MenuScreen("Welcome to the interactive TaPaSCo Debugger", vector<string>()) {
    options.push_back("Show kernel map of current bitstream");
    screens.push_back(new TapascoStatusScreen(&tapasco));
    options.push_back("Perform interrupt stress test");
    screens.push_back(new InterruptStressTestScreen(&tapasco));
    options.push_back("Monitor device registers");
    screens.push_back(new MonitorScreen(&tapasco));
    options.push_back("Monitor blue infrastructure");
    screens.push_back(new BlueDebugScreen(&tapasco));
    if (tapasco.has_capability(TAPASCO_DEVICE_CAP_ATSPRI) == TAPASCO_SUCCESS &&
        tapasco.has_capability(TAPASCO_DEVICE_CAP_ATSCHECK) == TAPASCO_SUCCESS) {
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
private:
  vector<Screen *> screens;
  Tapasco tapasco;
};

#endif /* TAPASCO_DEBUG_MENU_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
