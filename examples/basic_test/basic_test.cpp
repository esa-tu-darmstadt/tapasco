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
/**
 *  @file	basic_test.cpp
 *  @brief	Uses the precompiled basic_test bitstreams to run the absolute
 *              minimum of functionality tests: Test 1 uses 'arrayinit' to
 *              ascertain that masters on the device can write to memory; Test 2
 *              uses 'arraysum' to ascertain read capability in the same way and
 *              Test 3 executes 'warraw' which requires both (in-loop deps).
 *              Overall idea is to provide increase confidence in the basic
 *              functionality of the installation when debugging.
 *
 *              WORD OF CAUTION: THIS IS A HARDHAT AREA, HACKED IN <20 MIN!
 *              BEWARE OF HORRIBLE CODE AHEAD...
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <iostream>
#include <vector>
#include <future>
#include <atomic>
#include <cstdlib>
#include <unistd.h>
#include <assert.h>
#include <tapasco.hpp>

#define TEST_1
#define TEST_2
#define TEST_3

using namespace std;

#define SZ			256
#define RUNS			100000
#define T1_KID			11
#define T2_KID			10
#define T3_KID			 9

static tapasco::Tapasco Tapasco;
static atomic<int> runs;
typedef int run_block[SZ];

// #define CPU_EXECUTION 1
/******************************************************************************/
bool test1_execute(int *arr)
{
  int run;
  while ((run = runs--) >= 0) {
    run_block *z = reinterpret_cast<run_block *>(&arr[run * SZ]);
#ifdef CPU_EXECUTION
    for (int i = 0; i < SZ; ++i)
      (*z)[i] = i;
#else
    if (Tapasco.launch_no_return(T1_KID, tapasco::OutOnly<run_block>{z}) != tapasco::TAPASCO_SUCCESS)
      return false;
#endif
  }
  return true;
}

static void test1_prepare(int *arr)
{
  for (size_t j = 0; j < RUNS; ++j)
    for (size_t i = 0; i < SZ; ++i)
      arr[j * SZ + i] = -1;
}

static int test1_check(int *arr)
{
  int errs = 0;
  for (int i = 0; i < SZ; ++i) {
    if (arr[i] != i) {
      cerr << "wrong data at " << i << ": " << arr[i] << endl;
      ++errs;
    }
  }
  return errs;
}

/******************************************************************************/
static void test2_prepare(int *arr, size_t sz)
{
  for (size_t i = 0; i < sz; ++i)
    arr[i] = i;
}

int test2_execute(int *arr)
{
  int run;
  int result = 0;
  while ((run = runs--) >= 0) {
    const run_block *z = reinterpret_cast<const run_block *>(&arr[run * SZ]);
#ifdef CPU_EXECUTION
    for (int i = 0; i < SZ; ++i)
      result += (*z)[i];
#else
    int tr = 0;
    if (Tapasco.launch(T2_KID, tr, z) != tapasco::TAPASCO_SUCCESS)
      return -1;
    else
      result += tr;
#endif
  }
  return result;
}

static bool test2_check(int *arr, size_t sz, int res) {
  int golden = 0;
  for (size_t i = 0; i < sz; ++i)
    golden += arr[i];
  return golden == res;
}

/******************************************************************************/
static void test3_prepare(int *arr, size_t sz, size_t bsz)
{
  for (size_t i = 0; i < sz; ++i)
    arr[i] = i % bsz;
}

void test3_execute(int *arr)
{
  int run;
  while ((run = runs--) >= 0) {
    run_block *z = reinterpret_cast<run_block *>(&arr[run * SZ]);
#ifdef CPU_EXECUTION
    for (int i = 0; i < SZ; ++i)
      (*z)[i] += 42;
#else
    tapasco::tapasco_res_t res;
    if ((res = Tapasco.launch_no_return(T3_KID, z)) != tapasco::TAPASCO_SUCCESS)
      throw tapasco::Tapasco::tapasco_error(res);
#endif
  }
}

static unsigned int test3_check(int *arr, size_t sz)
{
  unsigned int errs = 0;
  for (int i = 0; i < (int)sz; ++i) {
    if (arr[i] != i + 42) {
      fprintf(stderr, "wrong data at %d: %d, should be %d\n",
          i, arr[i], i + 42);
      ++errs;
    }
  }
  return errs;
}
/******************************************************************************/
int main(int argc, char **argv)
{
  int retval = 0;
  unsigned int tc = 1; // sysconf(_SC_NPROCESSORS_CONF);
#ifndef CPU_EXECUTION
  if (!Tapasco.is_ready()) {
    cerr << "TPC init failed." << endl;
    sleep(10);
    return 1;
  }
  const uint32_t cnt[] = {
       Tapasco.func_instance_count(T1_KID),
       Tapasco.func_instance_count(T2_KID),
       Tapasco.func_instance_count(T3_KID),
  };
  cout << "Instance counts" << endl
       << "  arrayinit   : " <<  cnt[0] << endl
       << "  arraysum    : " <<  cnt[1] << endl
       << "  arrayupdate : " <<  cnt[2] << endl;

  if (cnt[0] == 0 || cnt[1] == 0 || cnt[2] == 0) {
    cerr << "ERROR: missing at least one of the required kernels!" << endl;
    return EXIT_FAILURE;
  }
#endif

  int *arr { new int[SZ * RUNS] };
  test1_prepare(arr);

  if (argc >= 2)
    tc = stoul(argv[1]);

  cout << "Using threadpool with " << tc << " threads." << endl;
  runs = RUNS - 1;

  int result { 0 };
  /****************************************************************************/
#ifdef TEST_1
  vector<future<bool> > tp;
  for (unsigned int i = 0; i < tc; ++i)
    tp.push_back(async(launch::async, test1_execute, arr));
  for (auto& f : tp)
    retval += f.get() ? 0 : 1;
  for (unsigned int i = 0; i < RUNS; ++i) {
    int err = test1_check(&arr[i * SZ]);
    cout << "Run #" << i << (err ? " NOT OK!" : " ok.") << endl;
    retval += err;
  }
#endif

  /****************************************************************************/
#ifdef TEST_2
  vector<future<int> > tp2;
  runs = RUNS - 1;
  test2_prepare(arr, SZ * RUNS);
  for (unsigned int i = 0; i < tc; ++i)
    tp2.push_back(async(launch::async, test2_execute, arr));
  for (auto& f : tp2)
    result += f.get();
  cout << "Test 2 " << (test2_check(arr, SZ * RUNS, result) ? " ok." : " NOT OK!") << endl;
  retval += test2_check(arr, SZ * RUNS, result) ? 0 : 1;
#endif

  /****************************************************************************/
#ifdef TEST_3
  vector<future<void> > tp3;
  runs = RUNS - 1;
  result = 0;
  test3_prepare(arr, SZ * RUNS, SZ);
  for (unsigned int i = 0; i < tc; ++i)
    tp3.push_back(async(launch::async, test3_execute, arr));
  for (auto& f : tp3)
    f.get();
  for (unsigned int i = 0; i < RUNS; ++i) {
    int errs = test3_check(&arr[i * SZ], SZ);
    cout << "Run #" << i << (errs ? " NOT OK!" : " ok.") << endl;
    retval += errs;
  }
#endif

  /****************************************************************************/
  cout << "Finished, errors: " << retval << endl;
  delete[] arr;
  return retval;
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
