/*
 * Copyright (c) 2014-2026 Embedded Systems and Applications, TU Darmstadt.
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
#ifndef EVENTFD_COMPAT_H_
#define EVENTFD_COMPAT_H_

#include <linux/eventfd.h>
#include <linux/version.h>

#ifndef RHEL_RELEASE_CODE
#define RHEL_RELEASE_CODE 0
#endif
#ifndef RHEL_RELEASE_VERSION
#define RHEL_RELEASE_VERSION(m, n) 1
#endif

static inline void compat_eventfd_signal(struct eventfd_ctx *efd, int n)
{
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 8, 0)) || RHEL_RELEASE_CODE >= RHEL_RELEASE_VERSION(9, 5)
	int i;
	for (i = 0; i < n; ++i)
		eventfd_signal(efd);
#else
	eventfd_signal(efd, n);
#endif
}

#endif