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
#include "cliparser.h"

CLIParser::CLIParser() {}

void CLIParser::parse_arguments(int argc, const char *argv[],
                                std::vector<std::string> &args) {
  bool last_value_missing = false;
  std::string last_key;
  for (unsigned int i = 1; i < (unsigned int)argc; ++i) {
    std::string line(argv[i]);
    bool is_key = false;
    if (line.compare("") != 0) {
      if (line[0] == '-') {
        if (line[1] == '-') {
          line = line.substr(2);
        } else {
          line = line.substr(1);
        }
        is_key = true;
      } else {
        if (last_value_missing && i != (unsigned int)argc - 1) {
          if (!is_valid_key(last_key, args)) {
            std::string excmsg = "unrecognized command line option \"";
            excmsg += last_key;
            excmsg += "\"";
            throw std::invalid_argument(excmsg);
          }
          // this must be the value of the last key
          cli_arguments[last_key] = line;
          last_value_missing = false;
        } else {
          // option: last element can be the plain file to process
          if (i == (unsigned int)argc - 1 &&
              cli_arguments.find("file") == cli_arguments.end()) {
            cli_arguments["file"] = line;
            return;
          } else {
            // invalid argument format
            throw std::invalid_argument(
                "invalid command line argument syntax!");
          }
        }
      }
      if (is_key && last_value_missing) {
        if (!is_valid_key(last_key, args)) {
          std::string excmsg = "unrecognized command line option \"";
          excmsg += last_key;
          excmsg += "\"";
          throw std::invalid_argument(excmsg);
        }
        cli_arguments[last_key] = "";
        last_value_missing = false;
      }
      std::vector<std::string> parts;
      tokenize(line, parts, '=');
      if (parts.size() == 1) {
        last_value_missing = true;
        last_key = parts[0];
      } else if (parts.size() == 2) {
        if (!is_valid_key(parts[0], args)) {
          std::string excmsg = "unrecognized command line option \"";
          excmsg += parts[0];
          excmsg += "\"";
          throw std::invalid_argument(excmsg);
        }
        cli_arguments[parts[0]] = parts[1];
      } else {
        // invalid argument format
        throw std::invalid_argument("invalid command line argument syntax!");
      }
    }
  }
  if (last_value_missing) {
    if (!is_valid_key(last_key, args)) {
      std::string excmsg = "unrecognized command line option \"";
      excmsg += last_key;
      excmsg += "\"";
      throw std::invalid_argument(excmsg);
    }
    cli_arguments[last_key] = "";
  }
}

bool CLIParser::insert_value(std::string key, std::string value) {
  if (!key_exists(key)) {
    cli_arguments[key] = value;
    return true;
  } else {
    return false;
  }
}

std::string CLIParser::getValue(std::string key) { return cli_arguments[key]; }

bool CLIParser::key_exists(std::string key) {
  if (cli_arguments.find(key) == cli_arguments.end()) {
    return false;
  } else {
    return true;
  }
}

bool CLIParser::is_valid_key(std::string key, std::vector<std::string> &args) {
  for (unsigned int i = 0; i < args.size(); ++i) {
    if (key.compare(args[i]) == 0) {
      return true;
    }
  }
  return false;
}
