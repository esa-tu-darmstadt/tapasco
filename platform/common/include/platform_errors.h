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
//! @file	platform_errors.h
//! @brief	Error messages and codes.
//! @authors	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __PLATFORM_API_ERROR_H__
#define __PLATFORM_API_ERROR_H__

#ifdef __cplusplus
namespace tapasco { namespace platform { extern "C" {
#endif /* __cplusplus */
/********************************************************************************/

#define PLATFORM_ERRORS \
	_X(PERR_NO_CONNECTION          , -1       , "no connection to simulator") \
	_X(PERR_OPEN_FILES_HARD_LIMIT  , -2       , "hard limit for number of open files insufficient") \
	_X(PERR_OPEN_FILES_SET_LIMIT   , -3       , "soft limit for number of open files could not be increased") \
	_X(PERR_OPEN_DEV               , -4       , "could not open device file") \
	_X(PERR_MMAP_DEV               , -5       , "could not mmap device file") \
	_X(PERR_MEM_ALLOC              , -6       , "could not allocate device memory") \
	_X(PERR_MEM_MMAP               , -7       , "could not mmap device memory") \
	_X(PERR_MEM_NO_SUCH_HANDLE     , -8       , "device memory with specified handle does not exist") \
	_X(PERR_MEM_NO_SUCH_BUFFER     , -9       , "device memory buffer with specified id does not exist") \
	_X(PERR_CTL_INVALID_ADDRESS    , -10      , "invalid ctl address") \
	_X(PERR_CTL_INVALID_SIZE       , -11      , "invalid read/write ctl size") \
	_X(PERR_IRQ_WAIT               , -12      , "waiting for interrupt failed") \
	_X(PERR_DMA_SYS_CALL           , -14      , "sys-call to dma engine went wrong") \
	_X(PERR_USER_SYS_CALL          , -15      , "sys-call to user registers went wrong") \
	_X(PERR_MEM_ALLOC_INVALID_SIZE , -16      , "invalid size for memory allocation") \
	_X(PERR_DMA_INVALID_ADDRESS    , -17      , "invalid dma address") \
	_X(PERR_DMA_INVALID_SIZE       , -18      , "invalid read/write dma size") \
	_X(PERR_VERSION_MISMATCH       , -19      , "Platform API version mismatch") \
	_X(PERR_NOT_IMPLEMENTED        , -20      , "not implemented") \
	_X(PERR_SENTINEL               , -21      , "--- no error, just end of list ---")

#ifdef _X
	#undef _X
#endif

#define _X(constant, code, msg) \
	constant = code,
/** internal type; complementary to platform_res_t */
typedef enum {
	PLATFORM_ERRORS
} platform_error_t;
#undef _X

/********************************************************************************/
#ifdef __cplusplus
} /* extern "C" */ } /* namespace platform */ } /* namespace tapasco */
#endif /* __cplusplus */

#endif /* __PLATFORM_API_ERROR_H__ */
