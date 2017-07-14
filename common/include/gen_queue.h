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
 *  @file	gen_queue.h
 *  @brief	Lock-free queue implementation based on the journal paper
 *  		"Nonblocking algorithms and preemption-safe locking on
 *  		multiprogrammed shared-memory multiprocessors." by M. Michael
 *  		and M. Scott (1998).
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef __GEN_QUEUE_H__
#define __GEN_QUEUE_H__

#ifdef __cplusplus
#include <atomic>
extern "C" {
#endif

/** @defgroup types Internal types
 *  @{
 **/

/** Tagged pointer type: pointer + update counter. **/
struct gq_tagged_ptr;

/** Queue element type. **/
struct gq_e_t;

/** Queue type. **/
struct gq_t;

/** @} **/


/** @defgroup ops FIFO operations
 *  @{
 **/

/**
 * Enqueue operation, pushes element to queue.
 * @param q pointer to queue struct
 * @param v value to push
 **/
void gq_enqueue(struct gq_t *q, void *v);

/**
 * Dequeue pops the "oldest" element in FIFO order.
 * @param q pointer to queue struct.
 * @return pointer to element, or NULL if empty
 **/
void *gq_dequeue(struct gq_t *q);

/** @} **/


/** @defgroup init Intialization
 *  @{
 **/

/**
 * Initializes a queue.
 * @param q pointer to queue struct
 **/
struct gq_t *gq_init(void);

/**
 * Destroys a queue and frees its backing memory.
 * Note: Does not currently free the memory for its elements!
 * @param q pointer to queue struct
 **/
void gq_destroy(struct gq_t *q);

/** @} **/

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif // __GEN_QUEUE_H__
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
