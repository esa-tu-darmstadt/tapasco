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
 *  @file       counter.h                                                       
 *  @brief      HLS implementation of a simple 32bit counter:
 *              Waits the number of clock cycles specified in first arg before
 *              raising the interrupt.
 *  @author     J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)               
 **/                                                                               
#ifndef __COUNTER_H__
#define __COUNTER_H__

#ifdef __cplusplus
#include <cstdint>
#else
#include <stdint.h>
#endif

uint32_t counter(const uint32_t clock_cycles);

#endif /* __COUNTER_H__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
