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
 *  @file	tapasco_logging_benchmark.h
 *  @brief	Logging mechanism benchmark.
 *  		Starts a number of threads to produce random log messages as
 *  		fast as possible and report the average throughput.
 *  		Random data is preallocated in memory block to avoid L2 effects.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TAPASCO_LOGGING_TEST_H__
#define TAPASCO_LOGGING_TEST_H__
#include <unistd.h>

// should exceed size of L2 cache to prevent caching effects
#define RANDOM_DATA_SZ					(64 * 1024 * 1024)
#define DEFAULT_LOGS					10000000
#define DEFAULT_THREADS					(sysconf(_SC_NPROCESSORS_CONF))

#endif /* TAPASCO_LOGGING_TEST_H__ */
