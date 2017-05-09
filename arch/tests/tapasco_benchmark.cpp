/**
 *  @file	tapasco_benchmark.cpp
 *  @brief	Benchmark application that generates a JSON file containing
 *              parameters for design space exploration. Also gives an overview
 *              of system performance.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <chrono>
#include <ctime>
#include <vector>
#include <sys/utsname.h>
#include <tapasco_api.hpp>
#include <platform_api.h>
#include "CumulativeAverage.hpp"
#include "TransferSpeed.hpp"
#include "InterruptLatency.hpp"
#include "json11.hpp"

using namespace std;
using namespace tapasco;
using namespace json11;

struct transfer_speed_t {
  size_t chunk_sz;
  double speed_r;
  double speed_w;
  double speed_rw;
  Json to_json() const { return Json::object {
      {"Chunk Size", static_cast<int>(chunk_sz)},
      {"Read", speed_r},
      {"Write", speed_w},
      {"ReadWrite", speed_rw}
    }; }
};


int main(int argc, const char *argv[]) {
  Tapasco tapasco;
  TransferSpeed tp { tapasco };
  InterruptLatency il { tapasco };
  struct utsname uts;
  uname(&uts);
  vector<Json> speed;
  struct transfer_speed_t ts;

  string platform = "vc709";
  if (argc < 2) {
    if (getenv("TAPASCO_PLATFORM") == NULL) {
      char n[256] { "" };
      cout << "Environment variable TAPASCO_PLATFORM is not set, guessing Platform ..." << endl;
      if (gethostname(n, 255))
        cerr << "Could not get host name, guessing vc709 Platform" << endl;
      else {
        cout << "Host name: " << n << endl;
	if (string(n).compare("zed") == 0 || string(n).compare("zedboard"))
	  platform = "zedboard";
	if (string(n).compare("zc706") == 0)
	  platform = "zc706";
	cout << "Guessing " << platform << " Platform" << endl;
      }
    } else platform = getenv("TAPASCO_PLATFORM");
  }

  // measure for chunk sizes 2^8 - 2^31 (2GB) bytes
  for (int i = 8; i < 32; ++i) {
    ts.chunk_sz = 1 << i;
    ts.speed_r  = tp(ts.chunk_sz, TransferSpeed::OP_COPYFROM);
    ts.speed_w  = tp(ts.chunk_sz, TransferSpeed::OP_COPYTO);
    ts.speed_rw = tp(ts.chunk_sz, TransferSpeed::OP_COPYFROM | TransferSpeed::OP_COPYTO);
    cout << "Transfer speed @ chunk_sz = " << (ts.chunk_sz/1024) << " KiB:" 
         << " read " << ts.speed_r << " MiB/s" 
         << ", write: " << ts.speed_w << " MiB/s"
	 << ", r/w: " << ts.speed_rw << " MiB/s"
	 << endl;
    Json json = ts.to_json();
    speed.push_back(json);
  }

  // measure average job roundtrip latency in the interval 1us - 100ms
  double const rl = il(0);
  cout << "Latency @ random runtime between 1us-100ms: " << rl << " us" << endl;

  // record current time
  time_t tt = chrono::system_clock::to_time_t(chrono::system_clock::now());
  tm tm = *localtime(&tt);
  stringstream str;
  str << put_time(&tm, "%Y-%m-%d %H:%M:%S");

  // build JSON object
  Json benchmark = Json::object {
    {"Timestamp", str.str()},
    {"Host", Json::object {
        {"Operating System", uts.sysname},
	{"Node", uts.nodename},
	{"Release", uts.release},
	{"Version", uts.version},
	{"Machine", uts.machine}
      }
    },
    {"Transfer Speed", speed},
    {"Job Roundtrip Overhead", rl},
    {"Library Versions", Json::object {
        {"TPC API", tapasco::tapasco_version()},
        {"Platform API", platform::platform_version()}
      }
    }
  };
  
  // dump it
  stringstream ss;
  ss << getenv("TAPASCO_HOME") << "/platform/" << platform << "/" << platform << ".benchmark";
  cout << "Dumping benchmark JSON to " << (argc >= 2 ? argv[1] : ss.str()) << endl;
  ofstream f(argc >= 2 ? argv[1] : ss.str());
  f << benchmark.dump();
  f.close();
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
