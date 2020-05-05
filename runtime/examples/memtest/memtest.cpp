#include <array>
#include <climits>
#include <iomanip>
#include <iostream>
#include <tapasco.hpp>

using namespace tapasco;

// runtime for random access benchmark in milliseconds
constexpr int random_time_ms = 1000;
// iterations for batch access benchmark
constexpr int batch_iterations = 1000;
// iterations for latency benchmark
constexpr int latency_iterations = 100000;
// whether to initialize the memory before the benchmarks (required for ECC
// memory) should later be determined automatically when the status core
// provides this information
constexpr bool ecc_memory = true;

constexpr int PE_ID = 321;
// column width used for printing the results in a table
constexpr int col_width = 20;
constexpr char space = ' ';

// determines smallest transfer size for batch; transfer size is
// 2^batch_min_length Bytes
constexpr int batch_min_length = 10;
// determines biggest transfer size for batch; transfer size is
// 2^batch_max_length Bytes
constexpr int batch_max_length = 25;

// number of different request sizes for random benchmark
constexpr int random_byte_length_c = 10;
// request sizes for random benchmark in bytes
constexpr int random_byte_length[random_byte_length_c] = {
    8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096};
constexpr int random_read_seed = 1234;
constexpr int random_write_seed = 5678;

double calcSpeed(unsigned long amount, unsigned long cycles, float clock) {
  // calculate transfer speed in GiB/s for given transfer amount (in bytes) and
  // time in cycles; clock speed is given in MHz
  return (amount / (cycles / (clock * 1000000.0))) / (1024 * 1024 * 1024);
}

void executeRandomBenchmark(tapasco::Tapasco &tapasco, int op,
                            unsigned long cycles, int byte_length,
                            float designclk) {
  char text[20];
  unsigned long ret = -1;
  tapasco::RetVal<unsigned long> ret_val(ret);
  // first argument is operation: 3 means Random Read, 4 Random Write, 5 Random
  // Read/Write second argument is runtime in cycles third argument is request
  // size in bytes (maximum 4096) fourth and fifth arguments are seeds for the
  // read and write address generation respectively
  auto job = tapasco.launch(PE_ID, ret_val, 3 + op, cycles, byte_length,
                            random_read_seed, random_write_seed);
  job();
  // when job is finished use return value (completed requests) to calculate
  // performance
  unsigned long total_data = byte_length * ret;
  double iops = ret / (cycles / (designclk * 1000000.0));
  snprintf(text, 20, "%.2fMIOPS", iops / 1000000);
  std::cout << left << setw(col_width) << setfill(space) << text;
  snprintf(text, 20, "%#.2fGiB/s", calcSpeed(total_data, cycles, designclk));
  std::cout << left << setw(col_width) << setfill(space) << text;
}

void benchmarkRandom(tapasco::Tapasco &tapasco, float designclk,
                     unsigned long cycles) {
  if (ecc_memory) {
    std::cout << "Initializing memory (required for ECC memory)" << std::endl;
    // To initialize memoryn write with biggest request size for double
    // benchmark time one time with read-address-seed second time with
    // write-address-seed this ensures all addresses which will later be
    // accessed were already initialized
    auto job = tapasco.launch(PE_ID, 4, 2 * cycles,
                              random_byte_length[random_byte_length_c - 1],
                              random_read_seed, random_read_seed);
    job();
    job = tapasco.launch(PE_ID, 4, 2 * cycles,
                         random_byte_length[random_byte_length_c - 1],
                         random_write_seed, random_write_seed);
    job();
  }
  std::cout << std::endl << std::endl;

  std::cout << "Random Access (" << cycles << " Cycles)" << std::endl
            << std::endl;

  // print table header
  std::cout << left << setw(col_width) << setfill(space) << "Size";
  std::cout << left << setw(2 * col_width) << setfill(space) << "Read";
  std::cout << left << setw(2 * col_width) << setfill(space) << "Write";
  std::cout << left << setw(2 * col_width) << setfill(space) << "Read/Write";
  std::cout << std::endl;

  // execute random benchmark for different request sizes
  for (int count = 0; count < random_byte_length_c; count++) {
    char text[20];
    snprintf(text, 20, "%iB", random_byte_length[count]);
    std::cout << left << setw(col_width) << setfill(space) << text;
    // Random Read
    executeRandomBenchmark(tapasco, 0, cycles, random_byte_length[count],
                           designclk);
    // Random Write
    executeRandomBenchmark(tapasco, 1, cycles, random_byte_length[count],
                           designclk);
    // Random Read/write
    executeRandomBenchmark(tapasco, 2, cycles, random_byte_length[count],
                           designclk);
    std::cout << std::endl;
  }
}

void printAsNano(double cycles, float clock) {
  // convert given number of cycles to nanoseconds and print; clock speed is in
  // MHz
  double nano = (cycles / clock) * 1000;
  char text[20];
  snprintf(text, 20, "%.2fns", nano);
  std::cout << left << setw(col_width) << setfill(space) << text;
}

void benchmarkLatency(tapasco::Tapasco &tapasco, float designclk) {
  std::cout << std::endl << std::endl;
  if (ecc_memory) {
    // Write to memory so the location is initialized
    auto prejob = tapasco.launch(PE_ID, 6, 0, 64, 1234);
    prejob();
  }
  std::cout << "Read Latency (" << latency_iterations << " Iterations)"
            << std::endl;
  std::cout << std::endl;
  unsigned long min = ULONG_MAX;
  unsigned long max = 0;
  unsigned long acc = 0;
  // execute given number of iterations
  for (int t = 0; t < latency_iterations; t++) {
    unsigned long ret = -1;
    tapasco::RetVal<unsigned long> ret_val(ret);
    // first argument is operation: 6 for Read Latency
    // second argument is ignored
    // third argument is request size
    // fourth argument is used as seed for memory address
    auto job = tapasco.launch(PE_ID, ret_val, 6, 0, 64, random_read_seed);
    job();
    // when job finished use return value (latency in cycles) to update
    // accumulator, minimum and maximum
    min = std::min(min, ret);
    max = std::max(max, ret);
    acc += ret;
  }
  // Calculate minimum, maximum and average latency in nanoseconds
  std::cout << left << setw(col_width) << setfill(space) << "Average:";
  printAsNano(((acc * 1.0) / latency_iterations), designclk);
  std::cout << std::endl;
  std::cout << left << setw(col_width) << setfill(space) << "Minimum:";
  printAsNano(min, designclk);
  std::cout << std::endl;
  std::cout << left << setw(col_width) << setfill(space) << "Maximum:";
  printAsNano(max, designclk);
  std::cout << std::endl;
}

void executeBatchBenchmark(tapasco::Tapasco &tapasco, float designclk, int op,
                           size_t size) {
  // calculate transfer size (2^size)
  size_t len = 1 << size;
  // used to accumulate return values over all iterations
  unsigned long acc = 0;
  // execute given number of iterations
  for (int i = 0; i < batch_iterations; i++) {
    unsigned long ret = 0;
    tapasco::RetVal<unsigned long> ret_val(ret);
    // first argument is operation: 0 for Batch Read, 1 for Batch Write, 2 for
    // Batch Read/Write second argument is unused third argument is transfer
    // size
    auto job = tapasco.launch(PE_ID, ret_val, op, 0, len);
    job();
    // when job finished add return value (transfer time in cycles) to
    // accumulator
    acc += ret;
  }
  // use accumulator to calculate performance
  unsigned long total_data = len * batch_iterations;
  // if operation is Read/Write len Bytes are read and len Bytes are written
  if (op == 2)
    total_data *= 2;
  char text[20];
  snprintf(text, 20, "%#.3fGiB/s", calcSpeed(total_data, acc, designclk));
  std::cout << left << setw(col_width) << setfill(space) << text;
}

void benchmarkBatch(tapasco::Tapasco &tapasco, float designclk) {
  std::cout << std::endl << std::endl;

  std::cout << "Batch Access (" << batch_iterations << " Iterations)"
            << std::endl
            << std::endl;

  // print table header
  std::cout << left << setw(col_width) << setfill(space) << "Size";
  std::cout << left << setw(col_width) << setfill(space) << "Read";
  std::cout << left << setw(col_width) << setfill(space) << "Write";
  std::cout << left << setw(col_width) << setfill(space) << "Read/Write";
  std::cout << std::endl;

  // execute batch benchmark for different transfer sizes
  for (size_t s = batch_min_length; s <= batch_max_length; s++) {
    char text[20];
    snprintf(text, 20, "%iKib", ((1 << s) / 1024));
    std::cout << left << setw(col_width) << setfill(space) << text;
    // Batch Read
    executeBatchBenchmark(tapasco, designclk, 0, s);
    // Batch Write
    executeBatchBenchmark(tapasco, designclk, 1, s);
    // Batch Read/Write
    executeBatchBenchmark(tapasco, designclk, 2, s);

    std::cout << std::endl;
  }
}

int main(int argc, char **argv) {
  // Initialize TaPaSCo
  tapasco::Tapasco tapasco;
  platform_info_t info;
  tapasco.info(&info);

  // Check PE count
  uint64_t instances = tapasco_device_kernel_pe_count(tapasco.device(), PE_ID);
  std::cout << "Got " << instances << " instances @ " << info.clock.design
            << "MHz" << std::endl;
  if (!instances) {
    std::cout << "Need at least one instance to run." << std::endl;
    exit(1);
  }

  // runtime for random access benchmark
  unsigned long cycles = random_time_ms * info.clock.design * 1000;

  benchmarkRandom(tapasco, info.clock.design, cycles);

  benchmarkBatch(tapasco, info.clock.design);

  benchmarkLatency(tapasco, info.clock.design);

  return 0;
}
