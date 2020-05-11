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
//! @file	tlkm_logging.h
//! @brief	Kernel logging for TaPaSCo unified loadable kernel module.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/stat.h>
#include <linux/types.h>
#include <linux/moduleparam.h>
#include "tlkm_logging.h"

#ifndef NDEBUG

ulong tlkm_logging_flags = 0xFFFFFFFF;
module_param(tlkm_logging_flags, ulong, S_IRUGO | S_IWUSR | S_IWGRP);
MODULE_PARM_DESC(tlkm_logging_flags, "bitfield, activates subsystem logging");

#endif /* NDEBUG */
