//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 *  @file	tpc_version.c
 *  @brief	Common implementations of the TPC version info functions.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <string.h>
#include <tpc_api.h>
#include <tpc_errors.h>

const char *const tpc_version()
{
	return TPC_API_VERSION;
}

tpc_res_t tpc_check_version(const char *const version)
{
	return strcmp(TPC_API_VERSION, version) ? TPC_ERR_VERSION_MISMATCH : TPC_SUCCESS;
}
