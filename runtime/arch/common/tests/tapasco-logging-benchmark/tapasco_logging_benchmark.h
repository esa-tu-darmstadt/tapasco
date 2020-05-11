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
#ifndef TAPASCO_LOGGING_TEST_H__
#define TAPASCO_LOGGING_TEST_H__
#include <unistd.h>

// should exceed size of L2 cache to prevent caching effects
#define RANDOM_DATA_SZ (64 * 1024 * 1024)
#define DEFAULT_LOGS 10000000
#define DEFAULT_THREADS (sysconf(_SC_NPROCESSORS_CONF))

#endif /* TAPASCO_LOGGING_TEST_H__ */
