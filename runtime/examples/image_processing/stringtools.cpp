/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
#include "stringtools.h"

void tokenize(std::string line, std::vector<std::string> &vec, char separator) {
  unsigned int last = 0;
  unsigned int length = 0;
  for (unsigned int i = 0; i < line.length(); ++i) {
    if (line[i] == separator) {
      std::string item = line.substr(last, length);
      vec.push_back(item);
      last = i + 1;
      length = 0;
    } else {
      ++length;
    }
  }
  if (line.length() >= 1) {
    if (line[line.length() - 1] != separator) {
      std::string item = line.substr(last, length);
      vec.push_back(item);
    }
  }
}

std::string trim(std::string &string) {
  std::string valid_chars =
      "qwertzuiopasdfghjklyxcvbnmQWERTZUIOPASDFGHJKLYXCVBNM1234567890.-+_/\\";
  std::size_t first = string.find_first_of(valid_chars);
  std::size_t last = string.find_last_of(valid_chars);
  return string.substr(first, last - first + 1);
}
