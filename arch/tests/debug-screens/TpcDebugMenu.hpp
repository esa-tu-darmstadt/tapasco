/**
 *  @file	TpcDebugMenu.hpp
 *  @brief	Main menu of tpc-debug.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef __TPC_DEBUG_MENU_HPP__
#define __TPC_DEBUG_MENU_HPP__

#include <tpc_api.hpp>
#include "MenuScreen.hpp"
#include "TpcStatusScreen.hpp"
#include "InterruptStressTestScreen.hpp"
#include "MonitorScreen.hpp"

using namespace tpc;

class TpcDebugMenu : public MenuScreen {
public:
  TpcDebugMenu() : MenuScreen("Welcome to the interactive TPC Debugger", vector<string>()) {
    options.push_back("Show kernel map of current bitstream");
    screens.push_back(new TpcStatusScreen(&tpc));
    options.push_back("Perform interrupt stress test");
    screens.push_back(new InterruptStressTestScreen(&tpc));
    options.push_back("Monitor device registers");
    screens.push_back(new MonitorScreen(&tpc));
    options.push_back("Exit");
  }
  virtual ~TpcDebugMenu() {
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
  ThreadPoolComposer tpc;
};

#endif /* __TPC_DEBUG_MENU_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
