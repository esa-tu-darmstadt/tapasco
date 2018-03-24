// // Copyright (C) 2018 Jens Korinth, TU Darmstadt
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
#ifndef ASYNC_H__
#define ASYNC_H__

#define PLATFORM_WAITFILENAME		"FFLINK_ASYNC"

int async_init(void);
void async_exit(void);

ssize_t async_signal_slot_interrupt(const u32 s_id);

#endif /*_ASYNC_H__ */
/* vim: set foldmarker=@{,}@ foldlevel=0 foldmethod=marker : */
