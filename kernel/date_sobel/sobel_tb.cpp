//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <chrono>
#include <thread>
#include <future>
#include <vector>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <assert.h>
#include <unistd.h>
#include <tpc_api.hpp>

#define __SYNTHESIS__
#include "sobel.cpp"

#define NOF_IMAGES 1024
#define KID 3915

using namespace std;
using namespace rpr::tpc;

struct Image {
  uint8_t data[IMAGE_SIZE * IMAGE_SIZE];

  Image()
  {
    fstream fs("/dev/urandom", fstream::in | ifstream::binary);
    assert(fs);
    fs.read((char *)data, sizeof(data));
    fs.close();
  }

  void dump(const string& filename) const
  {
    fstream fs(filename, fstream::out);
    assert(fs);
    fs << "P2" << endl << IMAGE_SIZE << " " << IMAGE_SIZE << " 255" << endl;
    for (int i = 0; i < IMAGE_SIZE * IMAGE_SIZE; ++i)
      fs << (int)data[i] << endl;
    fs.close();
  }
};

static atomic<int> jobs;

void execute(Image *image, Image *result)
{
  int c;
  while ((c = --jobs) >= 0)
    sobel(image[c].data, result[c].data);
}

void fpga_execute(TPC *tpc, Image *image, Image *result)
{
  int c;
  while ((c = --jobs) >= 0)
    tpc->launch_no_return(KID, image[c].data, result[c].data);
}

int main(int argc, char *argv[])
{
  int ret = 0;
  const auto com_start = chrono::steady_clock::now();
  const auto init_start = chrono::steady_clock::now();
  Image *images = new Image[NOF_IMAGES]();
  Image *result = new Image[NOF_IMAGES]();
  for (int i = 0; i < NOF_IMAGES; ++i)
    memcpy (result[i].data, images[i].data, IMAGE_SIZE * IMAGE_SIZE);
  const auto init_d = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - init_start);

  cerr << "Initialization took " << init_d.count() << " ms." << endl;

  for (int i = 0; i < NOF_IMAGES; ++i) {
    stringstream ss;
    ss << "initial_" << setw(3) << setfill('0') << i << ".ppm";
    images[i].dump(ss.str());
  }
  
  vector<future<void> > fs;
  jobs = NOF_IMAGES;
  auto total_start = chrono::steady_clock::now();
  for (int i = 0; i < sysconf(_SC_NPROCESSORS_CONF); ++i)
    fs.push_back(async(launch::async, execute, images, result));

  for (auto& f : fs)
    f.get();
  auto total_d = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - total_start);

  cout << "CPU took " << total_d.count() << " us." << endl;

#ifdef DUMP_IMAGES
  for (int i = 0; i < NOF_IMAGES; ++i) {
    stringstream ss;
    ss << "result_" << setw(3) << setfill('0') << i << ".ppm";
    result[i].dump(ss.str());
  }
#endif

  // reset output images for FPGA run
  fs.clear();
  for (int i = 0; i < NOF_IMAGES; ++i)
    memcpy (result[i].data, images[i].data, IMAGE_SIZE * IMAGE_SIZE);

  TPC tpc;
  assert(tpc.is_ready());
  unsigned int ninst = tpc.func_instance_count(KID);//sysconf(_SC_NPROCESSORS_CONF); //
  jobs = NOF_IMAGES;
  cerr << "Found " << ninst << " instances of Sobel kernel." << endl;
  total_start = chrono::steady_clock::now();
  for (unsigned int i = 0; i < ninst; ++i)
    fs.push_back(async(launch::async, fpga_execute, &tpc, images, result));
    //fs.push_back(async(launch::async, execute, images, result));
  for (auto& f : fs)
    f.get();
  total_d = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - total_start);

  cout << "FPGA took " << total_d.count() << " us." << endl;

#ifdef DUMP_IMAGES
  for (int i = 0; i < NOF_IMAGES; ++i) {
    stringstream ss;
    ss << "fpga_result_" << setw(3) << setfill('0') << i << ".ppm";
    result[i].dump(ss.str());
  }
#endif

  delete[] result;
  delete[] images;

#ifdef DUMP_IMAGES
  // now compare the results (simple binary file compare)
  for (int i = 0, ret = 0; !ret && i < NOF_IMAGES; ++i) {
    char buf_golden[4096], buf_fpga[4096];
    stringstream ss_golden, ss_fpga;
    ss_golden << "result_" << setw(3) << setfill('0') << i << ".ppm";
    ss_fpga << "fpga_result_" << setw(3) << setfill('0') << i << ".ppm";
    fstream golden(ss_golden.str(), istream::in);
    fstream fpga(ss_fpga.str(), istream::in);
    while (!ret && !golden.eof() && !fpga.eof()) {
      golden.read(buf_golden, sizeof(buf_golden));
      fpga.read(buf_fpga, sizeof(buf_fpga));
      ret = memcmp(buf_golden, buf_fpga, sizeof(buf_golden));
    }
    ret = ret || golden.eof() != fpga.eof();

    if (ret)
      cerr << "ERROR! images don't match: " << ss_golden.str() << " and " << ss_fpga.str() << endl;
  }
#endif
  auto com_d = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - com_start);
  cout << "Total elapsed time: " << com_d.count() << " ms." << endl;
  return ret;
}
