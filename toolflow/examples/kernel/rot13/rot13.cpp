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
 *  @file	rot13.cpp
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <iostream>
#include <unistd.h>
#include <cstring>
#include <cstdint>

using namespace std;

static constexpr size_t MAX_LEN = 4096;

static inline char char_rot13(const char c)
{
  if (c < 'A' || c > 'Z') return c;
  return c >= 'N' ? c - 13 : c + 13;
}

void rot13(uint32_t const len, char const text_in[MAX_LEN],
    char text_out[MAX_LEN])
{
  char buf_in[MAX_LEN], buf_out[MAX_LEN];
  memcpy(buf_in, text_in, len);
  for (size_t i = 0; i < len; ++i)
    buf_out[i] = char_rot13(buf_in[i]);
  memcpy(text_out, buf_out, len);
}

#ifndef __SYNTHESIS__
int main(int argc, char *argv[])
{
  int passed = EXIT_SUCCESS;
  char const *example[] = {
    "HELLO WORLD",
    "HELLO\tWORLD\nAGAIN",
    "12345",
    "ABCabc\tABC"
  };
  char const *expected[] = {
    "URYYB JBEYQ",
    "URYYB\tJBEYQ\nNTNVA",
    "12345",
    "NOPabc\tNOP"
  };
  char buf[MAX_LEN + 1];

  for (int unsigned i = 0; i < sizeof(example) / sizeof(*example); ++i) {
    int p;
    rot13(strlen(example[i]) + 1, example[i], buf);
    p = strncmp(buf, expected[i], strlen(expected[i]));
    passed = passed || p;
    cout << "TEST " << i << (p ? " FAILED!" : " PASSED") << endl;
  }
  return passed;
}
#endif

/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
