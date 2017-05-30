//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
#include <iostream>
#include <iomanip>
#include <fstream>
#include <string>
#include <cmath>
#include <chrono>
#include <thread>
#include <future>
#include <unistd.h>
#include <cassert>
#include <tapasco.hpp>
#include <platform.h>

#define MIN_NSECS          (10000)
#define MAX_NSECS          (1000000)
#define NSTEPS             (15)
#define JOBS               (10)

using namespace std;
using namespace tapasco::platform;

struct config_t {
  unsigned long int min;
  unsigned long int max;
  unsigned long int time_steps;
  unsigned long int iterations;
};

static long errors;

static tapasco::Tapasco Tapasco;

static inline void check_tapasco(tapasco::tapasco_res_t const result)
{
  if (result != tapasco::TAPASCO_SUCCESS) {
    cerr << "Tapasco fatal error: " << tapasco_strerror(result) << endl;
    exit(result);
  }
}

static inline uint32_t clock_period(void)
{
  static double period = 0.0;
  if (period == 0.0) {
    unsigned long hz;
    char buf[1024] = "";
    ifstream ifs("/sys/class/fclk/fclk0/set_rate", ifstream::in);
    if (! ifs.good()) {
      cerr << "WARNING: could not open /sys/class/fclk/fclk0/set_rate, using TAPASCO_FREQ" << endl;
      assert(getenv("TAPASCO_FREQ") && "must set TAPASCO_FREQ env var!");
      hz = stoi(string(getenv("TAPASCO_FREQ"))) * 1000000;
    } else {
      ifs.read(buf, sizeof(buf) - 1);
      cerr << "fclk/set_rate = " << buf << endl;
      hz = stoi(string(buf));
    }
    period = 1000000000.0 / hz;
    cerr << "period = " << period << " ns" << endl;
  }
  return nearbyint(period);
}

static inline unsigned long ns_to_cd(unsigned long ns) {
  return ns / clock_period();
}

static inline unsigned long cd_to_ns(unsigned long cd) {
  return cd * clock_period();
}

static inline uint32_t tapasco_run(uint32_t cc)
{
  uint32_t ret = 0;
  if (Tapasco.launch(14, ret, cc) != tapasco::TAPASCO_SUCCESS)
    __atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
  return ret;
}

static inline uint32_t platform_run(uint32_t cc)
{
  uint32_t start = 1;
  platform_ctl_addr_t sb = platform_address_get_slot_base(0, 0);
  if (platform_write_ctl(sb + 0x20, 4, &cc, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
    __atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
  if (platform_write_ctl_and_wait(sb, 4, &start, 0, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
    __atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
  // ack interrupt
  if (platform_write_ctl(sb + 0xc, 4, &start, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
    __atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
  if (platform_read_ctl(sb + 0x10, 4, &start, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
    __atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
  if (start != cc)
    cerr << "WARNING: found return value of " << start << " instead of expected " << cc << endl;
  return start;
}

static inline void print_header(void)
{
  cout << "Wait time (ns), Stopwatch Latency TPC (ns), Stopwatch Latency Platform (ns), "
       << "IRQ Ack. Latency TPC (ns), IRQ Ack. Latency Platform (ns)" << endl;
}

// static inline void print_line(double clk, unsigned long long t1, unsigned long long t2)
template <typename T1, typename T2>
static inline void print_line(const uint32_t clk, const T1& t1, const T1& t2, const T2& t3, const T2& t4)
{
  cout << fixed << setprecision(1)
       << clk << ", " << t1 << ", " << t2 << ", " << t3 << ", " << t4 << endl;
}

static inline void print_usage(void)
{
  cerr <<
    "Usage: benchmark-latency [<MIN_TIME> [<MAX_TIME> [<TIME_STEPS> [<ITERATIONS>]]]] with" << endl <<
    "\t<MIN_TIME>   = minimum kernel runtime in ns                (default: 10ns)" << endl <<
    "\t<MAX_TIME>   = maximum kernel runtime in ns                (default: 10000ns)" << endl <<
    "\t<TIME_STEPS> = number of equidistant sampling points       (default:10)" << endl <<
    "\t<ITERATIONS> = number of iterations at each sampling point (default:1000)"
    << endl << endl;
}

static inline void print_args(struct config_t const *cfg)
{
  cerr <<
    "Configuration:" << endl <<
    "\tminimum kernel time = " << cfg->min << endl <<
    "\tmaximum kernel time = " << cfg->max << endl <<
    "\tkernel time steps   = " << cfg->time_steps << endl <<
    "\titerations          = " << cfg->iterations << endl << endl;
}

static inline void parse_args(int argc, char **argv, struct config_t *cfg)
{
  // set defaults
  cfg->min        = 10000;
  cfg->max        = 1000000;
  cfg->time_steps = 100;
  cfg->iterations = 1000;

  // try to parse arguments (if some where given)
  if (argc > 1) cfg->min = stoi(string(argv[1]));
  if (argc > 2) cfg->max = stoi(string(argv[2]));
  if (argc > 3) cfg->time_steps = stoi(string(argv[3]));
  if (argc > 4) cfg->iterations = stoi(string(argv[4]));
  print_args(cfg);
}

int main(int argc, char **argv)
{
  struct config_t cfg;
  parse_args(argc, argv, &cfg);

  // initialize threadpool
  //check_Tapasco(Tapasco.init());
  uint32_t const n_inst = Tapasco.func_instance_count(14);
  cerr << "Found " << n_inst << " of timer kernel." << endl;
  if (! n_inst) {
    cerr << "ERROR: did not find any timer kernels." << endl;
    exit(EXIT_FAILURE);
  }

  unsigned long int clk_step = (cfg.max - cfg.min) / cfg.time_steps;
  unsigned long int clk = cfg.min;
  print_header();
  auto start = chrono::high_resolution_clock::now();
  for (unsigned int i = 0; i < cfg.time_steps; ++i, clk += clk_step) {
    const auto rounded_cd = ns_to_cd(clk);
    const auto rounded_clk = cd_to_ns(rounded_cd);
    uint64_t run_latencies = 0;
    uint64_t platform_latencies = 0;

    auto run_start = chrono::high_resolution_clock::now();
    for (unsigned int j = 0; j < cfg.iterations; ++j)
      run_latencies += tapasco_run(rounded_cd);
    auto run_d = chrono::duration_cast<chrono::nanoseconds>(chrono::high_resolution_clock::now() - run_start);
    auto run_time = run_d.count() / (double)cfg.iterations - (double)rounded_clk;

    //cerr << "run_latencies = " << run_latencies << endl;

    auto papi_start = chrono::high_resolution_clock::now();
    for (unsigned int j = 0; j < cfg.iterations; ++j)
      platform_latencies += platform_run(rounded_cd);
    auto papi_d = chrono::duration_cast<chrono::nanoseconds>(chrono::high_resolution_clock::now() - papi_start);
    auto papi_time = papi_d.count() / (double)cfg.iterations - (double)rounded_clk;

    //cerr << "platform_latencies = " << platform_latencies << endl;

    if (ns_to_cd(rounded_clk) != rounded_cd) cerr << " FUUUUUUUUUUUUUUUUUUUUUUUUUUU" << endl;
    run_latencies      *= clock_period();
    platform_latencies *= clock_period();
    run_latencies      /= cfg.iterations;
    platform_latencies /= cfg.iterations;
    print_line(rounded_clk, run_time, papi_time, run_latencies, platform_latencies);
  }
  auto total_d = chrono::duration_cast<chrono::microseconds>(chrono::high_resolution_clock::now() - start);
  cerr << "Total duration: " << total_d.count() << " us, errors: " <<  errors << endl;
}
