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
#include <csignal>
#include <vector>
#include <sys/utsname.h>
#include <tapasco_api.hpp>
#include <platform_api.h>
#include "CumulativeAverage.hpp"
#include "TransferSpeed.hpp"
#include "InterruptLatency.hpp"
#include "JobThroughput.hpp"
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

struct interrupt_latency_t {
  size_t cycle_count;
  double latency_us;
  double min_latency_us;
  double max_latency_us;
  Json to_json() const { return Json::object {
      {"Cycle Count", static_cast<double>(cycle_count)},
      {"Avg Latency", latency_us},
      {"Min Latency", min_latency_us},
      {"Max Latency", max_latency_us}
    }; }
};

struct job_throughput_t {
  size_t num_threads;
  double jobs_per_sec;
  Json to_json() const { return Json::object {
      {"Number of threads", static_cast<double>(num_threads)},
      {"Jobs per second", jobs_per_sec}
    }; }
};

void signalHandler(int sig) {
  cerr << "Signal %d received, aborting." << endl;
  endwin();
  exit(1);
}

int main(int argc, const char *argv[]) {
  // trap ctrl-c
  signal(SIGINT, signalHandler);
  try {
    Tapasco tapasco;
    TransferSpeed tp { tapasco };
    InterruptLatency il { tapasco };
    JobThroughput jt { tapasco };
    struct utsname uts;
    uname(&uts);
    vector<Json> speed;
    struct transfer_speed_t ts;
    vector<Json> latency;
    struct interrupt_latency_t ls;
    vector<Json> jobs;
    struct job_throughput_t js;

    string platform = "vc709";
    if (argc < 2) {
      if (getenv("TAPASCO_PLATFORM") == NULL) {
        char n[256] { "" };
        cout << "Environment variable TAPASCO_PLATFORM is not set, guessing Platform ..." << endl;
        if (gethostname(n, 255))
          cerr << "Could not get host name, guessing vc709 Platform" << endl;
        else {
          cout << "Host name: " << n << endl;
          platform = n;
          if (string(n).compare("zed") == 0 || string(n).compare("zedboard") == 0)
            platform = "zedboard";
          if (string(n).compare("zc706") == 0)
            platform = "zc706";
          cout << "Guessing " << platform << " Platform" << endl;
        }
      } else platform = getenv("TAPASCO_PLATFORM");
    }

    // measure for chunk sizes 2^10 (1KiB) - 2^31 (2GB) bytes
    for (int i = 10; i < 32; ++i) {
      ts.chunk_sz = 1 << i;
      ts.speed_r  = tp(ts.chunk_sz, TransferSpeed::OP_COPYFROM);
      ts.speed_w  = tp(ts.chunk_sz, TransferSpeed::OP_COPYTO);
      ts.speed_rw = tp(ts.chunk_sz, TransferSpeed::OP_COPYFROM | TransferSpeed::OP_COPYTO);
      cout << "Transfer speed @ chunk_sz = " << (ts.chunk_sz/1024) << " KiB:"
           << " read "    << ts.speed_r  << " MiB/s"
           << ", write: " << ts.speed_w  << " MiB/s"
           << ", r/w: "   << ts.speed_rw << " MiB/s"
           << endl;
      if (ts.speed_r > 0.0 || ts.speed_w > 0 || ts.speed_rw > 0) {
        Json json = ts.to_json();
        speed.push_back(json);
      } else break;
    }

    // measure average job roundtrip latency for clock cycles counts
    // between 2^0 and 2^31
    for (size_t i = 0; i < 32; ++i) {
      ls.cycle_count = 1UL << i;
      ls.latency_us  = il.atcycles(ls.cycle_count, 10, &ls.min_latency_us, &ls.max_latency_us);
      cout << "Latency @ " << ls.cycle_count << "cc runtime: " << ls.latency_us << " us" << endl;
      Json json = ls.to_json();
      latency.push_back(json);
    }

    size_t i = 1;
    double prev = -1;
    js.jobs_per_sec = -1;
    do {
      prev = js.jobs_per_sec;
      js.num_threads = i;
      js.jobs_per_sec = jt(i);
      ++i;
      jobs.push_back(js.to_json());
    } while (i <= 128 && (i <= 8 || js.jobs_per_sec > prev));

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
      {"Interrupt Latency", latency},
      {"Job Throughput", jobs},
      {"Library Versions", Json::object {
          {"Tapasco API",  tapasco::tapasco_version()},
          {"Platform API", platform::platform_version()}
        }
      }
    };

    // dump it
    stringstream ss;
    ss << platform << ".benchmark";
    cout << "Dumping benchmark JSON to " << (argc >= 2 ? argv[1] : ss.str()) << endl;
    ofstream f(argc >= 2 ? argv[1] : ss.str());
    f << benchmark.dump();
    f.close();
  } catch (...) {
    endwin();
    throw;
  }
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
