/**
 *  @file       JobThroughput.hpp
 *  @brief      Measures the maximal number of jobs per second.
 *              Requires counter cores (e.g., precision_counter); will trigger
 *              interrupts after 1cc runtime and count finished jobs. Useful
 *              upper bound for job throughput in the system.
 *              The design must run at 100 MHz (assumption of timing calc).
 *  @author  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef JOB_THROUGHPUT_HPP__
#define JOB_THROUGHPUT_HPP__

#include <atomic>
#include <future>
#include <mutex>
#include <vector>
#include <tapasco.hpp>
extern "C" {
#include <gen_queue.h>
#include <assert.h>
}

using namespace std; using namespace std::chrono;
using namespace tapasco;

class JobThroughput {
public:
  static tapasco_kernel_id_t const COUNTER_ID = 14;
  JobThroughput(Tapasco& tapasco, bool fast): tapasco(tapasco), jobs(0), fast(fast) {
    if (tapasco.kernel_pe_count(COUNTER_ID) < 1)
      throw "need at least one instance of 'Counter' (14) in bitstream";
    q = gq_init();
    assert(q);
  }
  virtual ~JobThroughput() {}

  double operator()(size_t const num_threads) {
    CumulativeAverage<double> cavg { 0 };
    jobs.store(0U);
    stop = false;
    vector<future<void> > threads;
    auto const t_start = high_resolution_clock::now();
    threads.push_back(async(launch::async, [&]() { collect(); }));
    for (size_t t = 0; t < num_threads; ++t)
      threads.push_back(async(launch::async, [&]() { run2(); }));
    do {
      std::ios_base::fmtflags coutf( cout.flags() );
      std::cout << "\rNum threads: " << std::dec << std::fixed << std::setw(4) << std::setprecision(0) << num_threads
                << ", Jobs/Second: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << cavg()
                << ", Max: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << cavg.max()
                << ", Min: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << cavg.min()
                << ", Precision: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << fabs(cavg.delta())
                << ", Samples: " << std::dec << std::setw(3) << cavg.size()
                << ", Waiting for: " << std::dec << std::fixed << std::setw(4) << std::setprecision(0) << job
                << std::flush;
      cout.flags( coutf );
      usleep(5000);
      auto const j = jobs.load();
      auto const t = high_resolution_clock::now();
      auto const s = duration_cast<seconds>(t - t_start);
      auto const v = s.count() > 0 ? static_cast<double>(j) / static_cast<double>(s.count()) : 0.0;
      if (v > 10.0) cavg.update(v);
    } while (((!fast && fabs(cavg.delta()) > 10.0) || cavg.size() < 5));
    stop = true;
    for (auto &f : threads)
      f.wait();

    std::ios_base::fmtflags coutf( cout.flags() );
    std::cout << "\rNum threads: " << std::dec << std::fixed << std::setw(4) << std::setprecision(0) << num_threads
              << ", Jobs/Second: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << cavg()
              << ", Max: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << cavg.max()
              << ", Min: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << cavg.min()
              << ", Precision: " << std::dec << std::fixed << std::setw(6) << std::setprecision(2) << fabs(cavg.delta())
              << ", Samples: " << std::dec << std::setw(3) << cavg.size()
              << ", Waiting for: " << std::dec << std::fixed << std::setw(4) << std::setprecision(0) << job
              << std::flush;
    cout.flags( coutf );

    std::cout << std::endl;

    return cavg();
  }

private:
  void run(void) {
    tapasco_res_t res;
    while (! stop) {
      if ((res = tapasco.launch(COUNTER_ID, 1U)()) != TAPASCO_SUCCESS)
        throw Tapasco::tapasco_error(res);
      jobs++;
    }
  }

  void run2() {
    while (! stop) {
      job_future *p = new job_future { tapasco.launch(COUNTER_ID, 0) };
      gq_enqueue(q, p);
    }
  }

  void collect(void) {
    job_future *jf { nullptr };
    while (! stop) {
      tapasco_res_t res { TAPASCO_SUCCESS };
      while ((jf = (job_future *)gq_dequeue(q))) {
        if ((res = (*jf)()) != TAPASCO_SUCCESS) {
          throw Tapasco::tapasco_error(res);
        }
        delete jf;
        ++jobs;
      }
    }
  }

  gq_t *q;
  Tapasco& tapasco;
  atomic<bool> stop { false };
  atomic<uint64_t> jobs { 0 };
  atomic<tapasco_job_id_t> job { 0 };
  bool fast;
};
#endif /* JOB_THROUGHPUT_HPP__ */
