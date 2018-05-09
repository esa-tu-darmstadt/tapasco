#include <iostream>
#include <vector>
#include <atomic>
#include <future>
#include <string>
#include <fstream>
#include <sstream>
#include <cstdint>
#include <unistd.h>
#include <tapasco.hpp>

extern "C" {
  #include "gen_queue.h"
}

using namespace std;
using namespace tapasco;

static constexpr tapasco_kernel_id_t COUNTER_ID { 14 };
static constexpr size_t INIT_SZ { 100000 };

static const string err_job { "could not get job id" };
static const string err_set { "could not set arg" };
static const string err_run { "failed to launch" };

struct Jobs {
  Jobs(): q(gq_init()), stop(false) {
    launched.reserve(INIT_SZ);
    collected.reserve(INIT_SZ);
  }
  virtual ~Jobs() { gq_destroy(q); }

  Tapasco tapasco;
  gq_t *q;
  atomic<bool> stop { false };
  vector<tapasco_job_id_t> launched;
  vector<tapasco_job_id_t> collected;
  vector<tapasco_slot_id_t> slots;
  vector<string> errors;
};

static
void launcher_thread(Jobs& j) {
  tapasco_job_id_t j_id { 0 };
  tapasco_res_t res { TAPASCO_SUCCESS };
  uint32_t cc = 1;
  while (! j.stop) {
    if ((res = tapasco_device_acquire_job_id(j.tapasco.device(), &j_id, COUNTER_ID, TAPASCO_DEVICE_ACQUIRE_JOB_ID_FLAGS_NONE)) != TAPASCO_SUCCESS) {
      j.errors.push_back(err_job);
      j.stop = true;
    }
    if ((res = tapasco_device_job_set_arg(j.tapasco.device(), j_id, 0, sizeof(cc), &cc)) != TAPASCO_SUCCESS) {
      j.errors.push_back(err_set);
      j.stop = true;
    }
    if ((res = tapasco_device_job_launch(j.tapasco.device(), j_id, TAPASCO_DEVICE_JOB_LAUNCH_NONBLOCKING)) != TAPASCO_SUCCESS) {
      j.errors.push_back(err_run);
      j.stop = true;
    }
    gq_enqueue(j.q, (void *)j_id);
    j.launched.push_back(j_id);
  }
}

static
void collector_thread(Jobs& j) {
  tapasco_res_t res;
  tapasco_job_id_t j_id { 0 };
  while (! j.stop) {
    while ((j_id = (tapasco_job_id_t)gq_dequeue(j.q))) {
      j.slots.push_back(tapasco_jobs_get_slot(j.tapasco.device()->jobs, j_id));
      if ((res = tapasco_device_job_collect(j.tapasco.device(), j_id)) != TAPASCO_SUCCESS) {
        stringstream ss;
	ss << "waiting for " << j_id << " failed: " << j_id << endl;
        j.errors.push_back(ss.str());
      	j.stop = true;
      }
      j.collected.push_back(j_id);
      tapasco_device_release_job_id(j.tapasco.device(), j_id);
    }
  }
}

static
void dump_data(Jobs &j) {
  ofstream ls("launched.txt", ofstream::out);
  ofstream cs("collected.txt", ofstream::out);
  ofstream ss("slots.txt", ofstream::out);
  for (auto j_id : j.launched)
    ls << j_id << endl;
  for (auto j_id : j.collected)
    cs << j_id << endl;
  for (auto s_id : j.slots)
    ss << s_id << endl;
}

int main(int argc, char *argv[])
{
  Jobs jobs;
  vector<future<void> > threads;
  if (jobs.tapasco.kernel_pe_count(COUNTER_ID) < 1) {
    cerr << "Requires at least one PE of a counter kernel (ID " << COUNTER_ID << ")." << endl;
    return EXIT_FAILURE;
  }
  threads.push_back(async(launch::async, [&]() { collector_thread(jobs); }));
  threads.push_back(async(launch::async, [&]() { launcher_thread(jobs); }));
  sleep(argc > 1 ? strtoul(argv[1], NULL, 0) : 5);

  jobs.stop = true;
  for (auto& t : threads)
    t.get();

  dump_data(jobs);

  for (auto s : jobs.errors)
    cerr << s << endl;
  return jobs.errors.size() > 0 ? 1 : 0;
}
