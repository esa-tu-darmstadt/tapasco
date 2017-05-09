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
#ifndef __RCU_COMMON_H__
#define __RCU_COMMON_H__

#include <stddef.h>

#ifdef __cplus_plus
extern "C" {
#endif

void dump_file(const char *fn, char *data, const size_t sz);

#ifdef __cplus_plus
} /* extern "C" */
#endif

#endif /* __RCU_COMMON_H__ */
