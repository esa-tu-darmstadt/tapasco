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
/**
 *  @file	platform_version.c
 *  @brief	Common implementations of the PAPI version info functions.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <string.h>
#include <platform.h>
#include <platform_errors.h>

const char *const platform_version()
{
	return PLATFORM_API_VERSION;
}

platform_res_t platform_check_version(const char *const version)
{
	return strcmp(PLATFORM_API_VERSION, version) ?
			PERR_VERSION_MISMATCH : PLATFORM_SUCCESS;
}
