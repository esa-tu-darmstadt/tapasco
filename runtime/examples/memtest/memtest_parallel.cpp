#include <array>
#include <iostream>
#include <tapasco.hpp>
#include <iomanip>
#include <climits>
#include <vector>

using namespace tapasco;

constexpr int random_time_ms = 1000;
constexpr int batch_iterations = 1000;
constexpr int latency_iterations = 100000;
constexpr bool ecc_memory = true;

constexpr int PE_ID = 321;
constexpr int col_width = 20;
constexpr char space = ' ';

constexpr int batch_min_length = 10;
constexpr int batch_max_length = 25;


constexpr int random_byte_length_c = 10;
constexpr int random_byte_length[random_byte_length_c] = {8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096};

double calcSpeed(unsigned long amount, unsigned long cycles, float clock) {
  return (amount / (cycles / (clock * 1000000.0))) / (1024*1024*1024);
}

void executeRandomBenchmark(tapasco::Tapasco &tapasco, int op, unsigned long cycles, int byte_length, float designclk, int instances) {
  char text[20];
  std::vector<tapasco::job_future> jobs;
  std::vector<tapasco::RetVal<unsigned long>> retvals;
  unsigned long rets[instances];
  for (int instance = 0; instance < instances; instance++) {
    rets[instance] = 0;
    tapasco::RetVal<unsigned long> ret_val(rets[instance]);
    retvals.push_back(ret_val);
    auto job = tapasco.launch(PE_ID, ret_val, 3 + op, cycles, byte_length, 1234, 5678);
    jobs.push_back(job);
  }
  unsigned long acc = 0;
  for (int instance = 0; instance < instances; instance++) {
    jobs[instance]();
    acc += retvals[instance].value;
    double iops = retvals[instance].value / (cycles / (designclk * 1000000.0));
    snprintf(text, 20, "%.2fMIOPS", iops / 1000000);
    std::cout << left << setw(col_width) << setfill(space) << text;
  }
  double iops = acc / (cycles / (designclk * 1000000.0));
  snprintf(text, 20, "%.2fMIOPS", iops / 1000000);
  std::cout << left << setw(col_width) << setfill(space) << text;
  sleep(1);
}

void benchmarkRandom(tapasco::Tapasco &tapasco, float designclk, unsigned long cycles, int instances) {
  std::cout << "Initializing memory (required for ECC memory)" << std::endl;
  if (ecc_memory) {
    auto job = tapasco.launch(PE_ID, 4, 2 * cycles, random_byte_length[random_byte_length_c - 1], 1234, 5678);
    job();
    sleep(1);
    job = tapasco.launch(PE_ID, 4, 2 * cycles, random_byte_length[random_byte_length_c - 1], 5678, 5678);
    job();
    sleep(1);
  }
  char text[20];
  std::cout << std::endl << std::endl;
  std::cout << "Random Access Read/Write (" << cycles << " Cycles)" << std::endl << std::endl;

  std::cout << left << setw(col_width) << setfill(space) << "Size";
  for (int instance = 0; instance < instances; instance++) {
    snprintf(text, 20, "Instance %i", instance);
    std::cout << left << setw(col_width) << setfill(space) << text;
  }
  std::cout << left << setw(col_width) << setfill(space) << "Total";
  std::cout << std::endl;

  for (int count = 0; count < random_byte_length_c; count++) {
    snprintf(text, 20, "%iB", random_byte_length[count]);
    std::cout << left << setw(col_width) << setfill(space) << text;
    executeRandomBenchmark(tapasco, 2, cycles, random_byte_length[count], designclk, instances);
    std::cout << std::endl;
  }

}


void executeBatchBenchmark(tapasco::Tapasco &tapasco, float designclk, int op, size_t size, int instances) {
  unsigned long acc = 0;
  size_t len = 1 << size;
  unsigned long accs[instances];
  for (int instance = 0; instance < instances; instance++) accs[instance] = 0;
  for (int i = 0; i < batch_iterations; i++) {
    std::vector<tapasco::job_future> jobs;
    std::vector<tapasco::RetVal<unsigned long>> retvals;
    unsigned long rets[instances];
    for (int instance = 0; instance < instances; instance++) {
      rets[instance] = 0;
      tapasco::RetVal<unsigned long> ret_val(rets[instance]);
      retvals.push_back(ret_val);
      auto job = tapasco.launch(PE_ID, ret_val, op, 0, len);
      jobs.push_back(job);
    }
    for (int instance = 0; instance < instances; instance++) {
      jobs[instance]();
      accs[instance] += retvals[instance].value;
      acc += retvals[instance].value;
    }
  }
  unsigned long total_data = len * batch_iterations;
  if (op == 2) total_data *= 2;
  char text[20];
  for (int instance = 0; instance < instances; instance++) {
    snprintf(text, 20, "%#.3fGiB/s", calcSpeed(total_data, accs[instance], designclk));
    std::cout << left << setw(col_width) << setfill(space) << text;
  }
  snprintf(text, 20, "%#.3fGiB/s", calcSpeed(total_data, acc, designclk));
  std::cout << left << setw(col_width) << setfill(space) << text;
}


void benchmarkBatch(tapasco::Tapasco &tapasco, float designclk, int instances) {
  char text[20];
  std::cout << std::endl << std::endl;

  std::cout << "Batch Access Read/Write (" << batch_iterations << " Iterations)" << std::endl << std::endl;

  std::cout << left << setw(col_width) << setfill(space) << "Size";
  for (int instance = 0; instance < instances; instance++) {
    snprintf(text, 20, "Instance %i", instance);
    std::cout << left << setw(col_width) << setfill(space) << text;
  }
  std::cout << left << setw(col_width) << setfill(space) << "Total";
  std::cout << std::endl;

  for (size_t s = batch_min_length; s <= batch_max_length; s++) {
    snprintf(text, 20, "%iKib", ((1 << s) / 1024));
    std::cout << left << setw(col_width) << setfill(space) << text;
    
    executeBatchBenchmark(tapasco, designclk, 2, s, instances);
    
    std::cout << std::endl;
  }
}

int main(int argc, char **argv) {
  tapasco::Tapasco tapasco;
  uint64_t instances = tapasco_device_kernel_pe_count(tapasco.device(), PE_ID);
  platform_info_t info;
  tapasco.info(&info);
  std::cout << "Got " << instances << " instances @ " << info.clock.design << "MHz" << std::endl;
  if (!instances || instances < 2) {
    std::cout << "Need at least two instance to run." << std::endl;
    exit(1);
  }

  unsigned long cycles = random_time_ms * info.clock.design * 1000;
  benchmarkRandom(tapasco, info.clock.design, cycles, instances);

  benchmarkBatch(tapasco, info.clock.design, instances);

  
  return 0;
}
