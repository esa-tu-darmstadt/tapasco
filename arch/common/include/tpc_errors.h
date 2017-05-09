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
//! @file	tpc_errors.h
//! @brief	Error messages and codes.
//! @authors	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __TPC_API_ERROR_H__
#define __TPC_API_ERROR_H__

#include <tpc_api.h>

#ifdef __cplusplus
namespace rpr { namespace tpc { extern "C" {
#endif /* __cplusplus */

#define TPC_ERRORS \
	_X(TPC_ERR_CONTEXT_NOT_AVAILABLE          , -1  , "no FPGA context available") \
	_X(TPC_ERR_DEVICE_NOT_FOUND               , -2  , "FPGA device not found") \
	_X(TPC_ERR_DEVICE_BUSY                    , -3  , "FPGA device is busy") \
	_X(TPC_ERR_NONBLOCKING_MODE_NOT_SUPPORTED , -4  , "non-blocking mode not supported") \
	_X(TPC_ERR_OUT_OF_MEMORY                  , -5  , "FPGA device out of memory") \
	_X(TPC_ERR_COPY_BUSY                      , -6  , "FPGA transfer could not be scheduled, device busy") \
	_X(TPC_ERR_NO_JOB_ID_AVAILABLE            , -7  , "no job id available, retry later") \
	_X(TPC_ERR_INVALID_ARG_INDEX              , -8  , "invalid kernel argument index") \
	_X(TPC_ERR_INVALID_ARG_SIZE               , -9  , "invalid kernel argument size") \
	_X(TPC_ERR_NOT_IMPLEMENTED                , -10 , "not implemented") \
	_X(TPC_ERR_JOB_ID_NOT_FOUND               , -11 , "job id not found") \
	_X(TPC_ERR_PLATFORM_FAILURE               , -12 , "platform failure, check log") \
	_X(TPC_ERR_STATUS_CORE_NOT_FOUND          , -13 , "TPC status core not found in bitstream") \
	_X(TPC_ERR_VERSION_MISMATCH               , -14 , "TPC API library version mismatch") \
	_X(TPC_ERR_SENTINEL                       , -15 , "--- no error just end of list ---")

#ifdef _X
	#undef _X
#endif

#define _X(constant, code, msg) \
	constant = code,
/** internal type; complementary to tpc_res_t */
typedef enum {
	TPC_ERRORS
} tpc_error_t;
#undef _X

#ifdef __cplusplus
} /* extern "C" */ } /* namespace tpc */ } /* namespace rpr */
#endif /* __cplusplus */

#endif /* __TPC_API_ERROR_H__ */
