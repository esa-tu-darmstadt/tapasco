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
//! @file	timer.h
//! @brief	C macros for high-precision timing (Linux, Mac OS X).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __TIMER_H__
#define __TIMER_H__

#ifdef __APPLE__
#include <stdint.h>
#include <mach/mach_time.h>

static mach_timebase_info_data_t _tb;

#define TIMER_INIT()	mach_timebase_info(&_tb);

#define TIMER_START(name) \
	uint64_t ts_start_##name = mach_absolute_time();

#define TIMER_STOP(name) \
	uint64_t ts_stop_##name = mach_absolute_time();

#define TIMER_USECS(name) \
	(uint64_t)((double)(ts_stop_##name - ts_start_##name) * \
			(double)_tb.numer / (double)_tb.denom / (double)1e3)

#else
#include <stdint.h>
#include <time.h>

static struct timespec _tb;

#define TIMER_INIT() \
	clock_getres(CLOCK_MONOTONIC, &_tb)

#define TIMER_START(name) \
	struct timespec tp_start_##name; \
	clock_gettime(CLOCK_MONOTONIC, &tp_start_##name);

#define TIMER_STOP(name) \
	struct timespec tp_stop_##name; \
	clock_gettime(CLOCK_MONOTONIC, &tp_stop_##name); \

#define TIMER_USECS(name) \
	tp_diff_usecs(&tp_stop_##name, &tp_start_##name)

static inline
unsigned long long tp_diff_usecs(struct timespec *stop, struct timespec *start)
{
	if (stop->tv_nsec < start->tv_nsec) {
		return (stop->tv_sec - 1 - start->tv_sec) * 1000000ULL +
				(1000000000ULL + stop->tv_nsec - start->tv_nsec) / 1000ULL;
	} else {
		return (stop->tv_sec - start->tv_sec) * 1000000ULL +
				(stop->tv_nsec - start->tv_nsec) / 1000ULL;
	}
}

#endif

#endif /* __TIMER_H__ */

