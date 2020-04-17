#include <array>
#include <iostream>
#include <tapasco.hpp>
#include <iomanip>
#include <climits>

using namespace tapasco;

constexpr int random_time_ms = 1000;
constexpr int batch_iterations = 1000;
constexpr int latency_iterations = 1000;
constexpr bool ecc_memory = true;

constexpr int PE_ID = 321;
constexpr int col_width = 15;
constexpr char space = ' ';

constexpr int batch_min_length = 10;
constexpr int batch_max_length = 26;


constexpr int random_byte_length_c = 10;
constexpr int random_byte_length[random_byte_length_c] = {8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096};

double calcSpeed(unsigned long amount, unsigned long cycles, float clock) {
  return (amount / (cycles / (clock * 1000000.0))) / (1024*1024*1024);
}

void executeRandomBenchmark(tapasco::Tapasco &tapasco, int op, unsigned long cycles, int byte_length, float designclk) {
  char text[20];
  sprintf(text, "%iB", byte_length);
  std::cout << left << setw(col_width) << setfill(space) << text;
  unsigned long ret = -1;
  tapasco::RetVal<unsigned long> ret_val(ret);
  auto job = tapasco.launch(PE_ID, ret_val, 3 + op, cycles, byte_length, 1234, 5678);
  job();
  unsigned long total_data = byte_length * ret;
  double iops = ret / (cycles / (designclk * 1000000.0));
  sprintf(text, "%.2fMIOPS", iops / 1000000);
  std::cout << left << setw(col_width) << setfill(space) << text;
  sprintf(text, "%#.2fGiB/s", calcSpeed(total_data, cycles, designclk));
  std::cout << left << setw(col_width) << setfill(space) << text;
  std::cout << left << setw(col_width) << setfill(space) << ret;
  sprintf(text, "%#.2fGiB", total_data / (1024.0*1024*1024));
  std::cout << left << setw(col_width) << setfill(space) << text;
  std::cout << std::endl;
  sleep(1);
}

void benchmarkRandomOp(tapasco::Tapasco &tapasco, int op, float designclk, unsigned long cycles) {
  std::cout << left << setw(col_width) << setfill(space) << "Size";
  std::cout << left << setw(col_width) << setfill(space) << "IOPS";
  std::cout << left << setw(col_width) << setfill(space) << "Byterate";
  std::cout << left << setw(col_width) << setfill(space) << "Transfers";
  std::cout << left << setw(col_width) << setfill(space) << "Total Transf.";

  std::cout << cycles << " Cycles" << std::endl;
  
  for (int count = 0; count < random_byte_length_c; count++) {
    executeRandomBenchmark(tapasco, op, cycles, random_byte_length[count], designclk);
  }
}

void benchmarkRandom(tapasco::Tapasco &tapasco, float designclk, unsigned long cycles) {


  if (ecc_memory) {
    benchmarkRandomOp(tapasco, 1, designclk, cycles * 2); 
  }


  std::cout << "Random Write" << std::endl;
  benchmarkRandomOp(tapasco, 1, designclk, cycles);
  std::cout << "Random Read" << std::endl;
  benchmarkRandomOp(tapasco, 0, designclk, cycles);
  std::cout << "Random Read/Write" << std::endl;
  benchmarkRandomOp(tapasco, 2, designclk, cycles);
}


void printAsNano(double cycles, float clock) {
  double nano = (cycles / clock) * 1000;
  char text[20];
  sprintf(text, "%.2fns", nano);
  std::cout << left << setw(col_width) << setfill(space) << text; 
}

void benchmarkLatency(tapasco::Tapasco &tapasco, float designclk) {
  std::cout << "Read Latency" << std::endl;
  std::cout << left << setw(col_width) << setfill(space) << "Average";
  std::cout << left << setw(col_width) << setfill(space) << "Minimum";
  std::cout << left << setw(col_width) << setfill(space) << "Maximum";
  std::cout << std::endl;
  for (size_t s = batch_min_length; s <= batch_max_length; ++s) {
    size_t len = 1 << s;
    unsigned long min = ULONG_MAX;
    unsigned long max = 0;
    unsigned long acc = 0;
    for (int t = 0; t < latency_iterations; t++) {
      unsigned long ret = -1;
      tapasco::RetVal<unsigned long> ret_val(ret);
      auto job = tapasco.launch(PE_ID, ret_val, 6, len, 1234);
      job();
      min = std::min(min, ret);
      max = std::max(max, ret);
      acc += ret;
    }
    printAsNano(((acc * 1.0) / latency_iterations), designclk);
    printAsNano(min, designclk);
    printAsNano(max, designclk);
    std::cout << std::endl;
  }
}

void executeBatchBenchmark(tapasco::Tapasco &tapasco, float designclk, int op, size_t size) {
  unsigned long acc = 0;
  size_t len = 1 << size;
  for (int i = 0; i < batch_iterations; i++) {
    unsigned long ret = 0;
    tapasco::RetVal<unsigned long> ret_val(ret);
    auto job = tapasco.launch(PE_ID, ret_val, op, len);
    job();
    acc += ret;
  }
  unsigned long total_data = len * batch_iterations;
  if (op == 2) total_data *= 2;
  char text[20];
  sprintf(text, "%#.3fGiB/s", calcSpeed(total_data, acc, designclk));
  std::cout << left << setw(col_width) << setfill(space) << text;
}

void benchmarkBatchOp(tapasco::Tapasco &tapasco, float designclk, int op) {
  std::cout << left << setw(col_width) << setfill(space) << "Ports";
  for (size_t s = batch_min_length; s <= batch_max_length; s++) {
    char text[20];
    sprintf(text, "%iKiB", ((1 << s) / 1024));
    std::cout << left << setw(col_width) << setfill(space) << text;
  }
  std::cout << std::endl;
  for (size_t s = batch_min_length; s <= batch_max_length; ++s) {
    executeBatchBenchmark(tapasco, designclk, op, s);
  }
  
}

void benchmarkBatch(tapasco::Tapasco &tapasco, float designclk) {
  std::cout << std::endl << "Batch Write" << std::endl << std::endl;
  benchmarkBatchOp(tapasco, designclk, 0);


  std::cout << std::endl << "Batch Read" << std::endl << std::endl;
  benchmarkBatchOp(tapasco, designclk, 1);


  std::cout << std::endl << "Batch Read/Write" << std::endl << std::endl;
  benchmarkBatchOp(tapasco, designclk, 2);
}

int main(int argc, char **argv) {
  tapasco::Tapasco tapasco;
  uint64_t instances = tapasco_device_kernel_pe_count(tapasco.device(), PE_ID);
  platform_info_t info;
  tapasco.info(&info);
  std::cout << "Got " << instances << " instances @ " << info.clock.design << "MHz" << std::endl;
  if (!instances) {
    std::cout << "Need at least one instance to run." << std::endl;
    exit(1);
  }

  unsigned long cycles = random_time_ms * info.clock.design * 1000;
  benchmarkRandom(tapasco, info.clock.design, cycles);

  benchmarkBatch(tapasco, info.clock.design);

  benchmarkLatency(tapasco, info.clock.design);
  
  return 0;
}
