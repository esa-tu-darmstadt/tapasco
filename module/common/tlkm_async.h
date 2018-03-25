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
//! @file	tlkm_async.h
//! @brief	Defines the asynchronous job completion device file for the
//!             unified TaPaSCo loadable kernel module.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TLKM_ASYNC_H__
#define TLKM_ASYNC_H__

#define TLKM_ASYNC_FILENAME		"tlkm_async"

int  tlkm_async_init(void);
void tlkm_async_exit(void);

ssize_t tlkm_async_signal_slot_interrupt(const u32 s_id);

#endif /* TLKM_ASYNC_H__ */
