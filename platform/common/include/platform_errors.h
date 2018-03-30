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

#define PLATFORM_ERRORS \
	_X(PERR_NO_CONNECTION          , -1       , "no connection to simulator") \
	_X(PERR_OUT_OF_MEMORY          , -2       , "out of memory (host)") \
	_X(PERR_NO_DEVICES_FOUND       , -3       , "no devices found") \
	_X(PERR_OPEN_FILES_HARD_LIMIT  , -4       , "hard limit for number of open files insufficient") \
	_X(PERR_OPEN_FILES_SET_LIMIT   , -5       , "soft limit for number of open files could not be increased") \
	_X(PERR_OPEN_DEV               , -6       , "could not open device file") \
	_X(PERR_MMAP_DEV               , -7       , "could not mmap device file") \
	_X(PERR_MEM_ALLOC              , -8       , "could not allocate device memory") \
	_X(PERR_MEM_MMAP               , -9       , "could not mmap device memory") \
	_X(PERR_MEM_NO_SUCH_HANDLE     , -10       , "device memory with specified handle does not exist") \
	_X(PERR_MEM_NO_SUCH_BUFFER     , -11       , "device memory buffer with specified id does not exist") \
	_X(PERR_CTL_INVALID_ADDRESS    , -12      , "invalid ctl address") \
	_X(PERR_CTL_INVALID_SIZE       , -13      , "invalid read/write ctl size") \
	_X(PERR_IRQ_WAIT               , -14      , "waiting for interrupt failed") \
	_X(PERR_DMA_SYS_CALL           , -15      , "sys-call to dma engine went wrong") \
	_X(PERR_USER_SYS_CALL          , -16      , "sys-call to user registers went wrong") \
	_X(PERR_MEM_ALLOC_INVALID_SIZE , -17      , "invalid size for memory allocation") \
	_X(PERR_DMA_INVALID_ADDRESS    , -18      , "invalid dma address") \
	_X(PERR_DMA_INVALID_SIZE       , -19      , "invalid read/write dma size") \
	_X(PERR_VERSION_MISMATCH       , -20      , "Platform API version mismatch") \
	_X(PERR_NOT_IMPLEMENTED        , -21      , "not implemented") \
	_X(PERR_NO_PE_LOCAL_MEMORY     , -22      , "PE-local memory not available") \
	_X(PERR_STATUS_CORE_NOT_FOUND  , -23      , "TaPaSCO status core not found, invalid bitstream") \
	_X(PERR_ADDR_INVALID_COMP_ID   , -24      , "invalid platform component id") \
	_X(PERR_ADDR_INVALID_SLOT_ID   , -25      , "invalid slot id") \
	_X(PERR_INCOMPATIBLE_BITSTREAM , -26      , "incompatible bitstream") \
	_X(PERR_COMPONENT_NOT_FOUND    , -27      , "component not found in bitstream") \
	_X(PERR_PTHREAD_ERROR          , -28      , "pthread error") \
	_X(PERR_TLKM_ERROR             , -29      , "tlkm error") \
	_X(PERR_SENTINEL               , -30      , "--- no error, just end of list ---")

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

#endif /* __PLATFORM_API_ERROR_H__ */
