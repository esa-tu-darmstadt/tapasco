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
#ifndef __CLIPARSER_H_
#define __CLIPARSER_H_

#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

#include "stringtools.h"

class CLIParser {
public:
  CLIParser();
  void parse_arguments(int argc, const char *argv[],
                       std::vector<std::string> &args);
  std::string getValue(std::string key);
  bool insert_value(std::string key, std::string value);
  bool key_exists(std::string key);

private:
  std::map<std::string, std::string> cli_arguments;

  bool is_valid_key(std::string key, std::vector<std::string> &args);
};

#endif
