#ifndef __STRINGTOOLS_H_
#define __STRINGTOOLS_H_

#include <string>
#include <vector>

void tokenize(std::string line, std::vector<std::string> &vec, char separator);
std::string trim(std::string &string);

#endif
