//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
#ifndef _LOGGER_HPP_
#define _LOGGER_HPP_

#include <iostream>
#include <sstream>
#include <string>

/* consider adding boost thread id since we'll want to know whose writting and
 * won't want to repeat it for every single call */

/* consider adding policy class to allow users to redirect logging to specific
 * files via the command line
 */

enum loglevel_e
    {logERROR, logWARNING, logINFO, logDEBUG, logDEBUG1, logDEBUG2, logDEBUG3, logDEBUG4};

class logIt
{
public:
    logIt(loglevel_e _loglevel = logERROR, std::string s="") {
        _buffer << _loglevel << ":" << s << "\n"
            << std::string(
                _loglevel > logDEBUG 
                ? (_loglevel - logDEBUG) * 4 
                : 1
                , ' ');
    }

    template <typename T>
    logIt & operator<<(T const & value)
    {
        _buffer << value;
        return *this;
    }

    ~logIt()
    {
        _buffer << std::endl;
        // This is atomic according to the POSIX standard
        // http://www.gnu.org/s/libc/manual/html_node/Streams-and-Threads.html
        std::cerr << _buffer.str();
    }

private:
    std::ostringstream _buffer;
};

// define global logging level
extern loglevel_e loglevel;
// backup loglevel for local change
extern loglevel_e loglevel_last;

void change_log_level(loglevel_e level);
void resume_log_level();

#define log(level) \
if (level > loglevel) ; \
else logIt(level, __func__)

#endif
