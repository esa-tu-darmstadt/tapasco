#ifndef __CLIPARSER_H_
#define __CLIPARSER_H_

#include <iostream>
#include <stdexcept>
#include <string>
#include <map>
#include <vector>

#include "stringtools.h"

class CLIParser{
public:
	CLIParser();
	void parse_arguments(int argc, const char *argv[], std::vector<std::string> &args);
	std::string getValue(std::string key);
	bool insert_value(std::string key, std::string value);
	bool key_exists(std::string key);
private:
	std::map<std::string,std::string> cli_arguments;

	bool is_valid_key(std::string key, std::vector<std::string> &args);
};

#endif
