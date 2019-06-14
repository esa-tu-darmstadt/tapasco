//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
//! @file	tlkm_perfc_miscdev.h
//! @brief	Misc device interface to TaPaSCo performance counters.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TLKM_PERFC_MISCDEV_H__
#define TLKM_PERFC_MISCDEV_H__

#ifndef NPERFC

#include "tlkm_device.h"

int  tlkm_perfc_miscdev_init(struct tlkm_device *dev);
void tlkm_perfc_miscdev_exit(struct tlkm_device *dev);

#else /* NPERFC */

#define  tlkm_perfc_miscdev_init(...)				(0)
#define  tlkm_perfc_miscdev_exit(...)

#endif /* NPERFC */
#endif /* TLKM_PERFC_MISCDEV_H__ */
