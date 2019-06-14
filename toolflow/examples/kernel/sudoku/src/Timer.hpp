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
#ifndef __TIMER_HPP__
#define __TIMER_HPP__

#include <time.h>
#include <assert.h>

#ifdef __MACH__
#include <mach/clock.h>
#include <mach/mach.h>
#endif

class Timer
{
public:
	Timer() : stopped(false)
	{
#ifdef __MACH__
		host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &cclock);
#endif
	}
	~Timer()
	{
#ifdef __MACH__
		mach_port_deallocate(mach_task_self(), cclock);
#endif
	}

	void start()
	{
#ifdef __MACH__
		clock_get_time(cclock, &mts);
		_start.tv_sec = mts.tv_sec;
		_start.tv_nsec = mts.tv_nsec;
#else
		clock_gettime(CLOCK_REALTIME, &_start);
#endif
		_nsecs = 0;
		stopped = false;
	}
	void stop()
	{
#ifdef __MACH__
		clock_get_time(cclock, &mts);
		_end.tv_sec = mts.tv_sec;
		_end.tv_nsec = mts.tv_nsec;
#else
		clock_gettime(CLOCK_REALTIME, &_end);
#endif
		_nsecs = diff(_start, _end);
		stopped = true;
	}
	long long nano_secs() { assert(stopped); return _nsecs; }
	long long micro_secs() { assert(stopped); return _nsecs / 1000LL; }
	long long milli_secs() { assert(stopped); return _nsecs / 1000000LL; }

	static
#ifdef __MACH__
	long long resolution_in_ns(const clock_id_t clk_id)
#else
	long long resolution_in_ns(const clockid_t clk_id)
#endif
	{
#ifdef __MACH__
		clock_res_t mres;
		clock_get_res(mach_task_self(), &mres);
		return (long long)mres;
#else
		struct timespec res;
		clock_getres(clk_id, &res);
		return res.tv_nsec;
#endif
	}

	static
#ifdef __MACH__
	long long resolution_in_us(const clock_id_t clk_id)
#else
	long long resolution_in_us(const clockid_t clk_id)
#endif
	{
		return resolution_in_ns(clk_id) / 1000LL;
	}

private:
	static long long diff(const struct timespec &start,
			const struct timespec &end)
	{
		struct timespec temp;
		if ((end.tv_nsec - start.tv_nsec) < 0) {
			temp.tv_sec = end.tv_sec - start.tv_sec - 1;
			temp.tv_nsec = 1000000000LL + end.tv_nsec - start.tv_nsec;
		} else {
			temp.tv_sec = end.tv_sec - start.tv_sec;
			temp.tv_nsec = end.tv_nsec - start.tv_nsec;
		}
		return temp.tv_sec * 1000000000LL + temp.tv_nsec;
	}

	struct timespec _start;
	struct timespec _end;
	long long _nsecs;
	bool stopped;
#ifdef __MACH__
	clock_serv_t cclock;
	mach_timespec_t mts;
#endif
};

#endif /* __TIMER_H__ */
