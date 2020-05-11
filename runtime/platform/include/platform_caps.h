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
#ifndef PLATFORM_CAPS_H__
#define PLATFORM_CAPS_H__

/**
 * NOTE: the enum definitions are parsed by a rather primitive regex in Tcl; so
 * make sure not to use any references or complex expressions, the tcl expr
 * command must be able to interpret the RHS. Especially, take care to keep the
 * trailing ',', even on the last item.
 **/
typedef enum {
  PLATFORM_CAP0_ATSPRI = (1 << 0),
  PLATFORM_CAP0_ATSCHECK = (1 << 1),
  PLATFORM_CAP0_PE_LOCAL_MEM = (1 << 2),
  PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP = (1 << 3),
  PLATFORM_CAP0_AWS_EC2_PLATFORM = (1 << 6),
} platform_capabilities_0_t;

#define PLATFORM_VERSION_MAJOR(v) ((v) >> 16)
#define PLATFORM_VERSION_MINOR(v) ((v)&0xFFFF)

#endif /* PLATFORM_CAPS_H__ */
