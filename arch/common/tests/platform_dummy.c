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
//! @file	platform_dummy.c
//! @brief	Dummy implementations of Platform API calls to preven linker
//!		errors.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <platform.h>

platform_res_t platform_read_mem(
		platform_mem_addr_t const start_addr,
		size_t const no_of_bytes,
		void *data,
		platform_mem_flags_t const flags)
{
	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_mem(
		platform_mem_addr_t const start_addr,
		size_t const no_of_bytes,
		void const*data,
		platform_mem_flags_t const flags)
{
	return PLATFORM_SUCCESS;
}

platform_res_t platform_read_ctl(
		platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes,
		void *data,
		platform_ctl_flags_t const flags)
{
	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_ctl(
		platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes,
		void const*data,
		platform_ctl_flags_t const flags)
{
	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_ctl_and_wait(
		platform_ctl_addr_t const w_addr,
		size_t const w_no_of_bytes,
		void const *w_data,
		uint32_t const event,
		platform_ctl_flags_t const flags)
{
	return PLATFORM_SUCCESS;
}
