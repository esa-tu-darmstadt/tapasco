#include "stringtools.h"

void tokenize(std::string line, std::vector<std::string> &vec, char separator){
	unsigned int last = 0;
	unsigned int length = 0;
	for(unsigned int i=0; i<line.length(); ++i){
		if(line[i]==separator){
			std::string item = line.substr(last,length);
			vec.push_back(item);
			last = i+1;
			length = 0;
		}else{
			++length;
		}
	}
	if(line.length() >= 1){
		if(line[line.length()-1]!=separator){
			std::string item = line.substr(last,length);
			vec.push_back(item);
		}
	}
}

std::string trim(std::string &string){
	std::string valid_chars = "qwertzuiopasdfghjklyxcvbnmQWERTZUIOPASDFGHJKLYXCVBNM1234567890.-+_/\\";
	std::size_t first = string.find_first_of(valid_chars);
	std::size_t last = string.find_last_of(valid_chars);
	return string.substr(first,last-first+1);
}

