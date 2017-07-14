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
 *  @file	gen_queue.c
 *  @brief	Lock-free queue implementation based on the journal paper
 *  		"Nonblocking algorithms and preemption-safe locking on
 *  		multiprogrammed shared-memory multiprocessors." by M. Michael
 *  		and M. Scott (1998).
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/

#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#ifdef __STDC_NO_ATOMICS__
#error "C/C++ compiler does not have atomics"
#endif
#include <stdatomic.h>
#include "gen_queue.h"

#define TAGGED_PTR(n) struct gq_tagged_ptr n __attribute__ ((aligned(16)))

/** @defgroup types Internal types
 *  @{
 **/

/** Tagged pointer type: pointer + update counter. **/
struct gq_tagged_ptr {
	struct gq_e_t *ptr __attribute__ ((aligned(16)));
	unsigned long int tag __attribute__ ((packed));
};

/** Queue element type. **/
struct gq_e_t {
	_Atomic(struct gq_tagged_ptr) next;
	_Atomic(struct gq_tagged_ptr) prev;
	void *data;
};

/** Queue type. **/
struct gq_t {
	_Atomic(struct gq_tagged_ptr) tail;
	_Atomic(struct gq_tagged_ptr) head;
};
/** @} **/

/** @defgroup ops FIFO operations
 *  @{
 **/

/** Internal: compare tagged pointers. **/
static inline bool _gq_pointers_equal(struct gq_tagged_ptr a, struct gq_tagged_ptr b)
{
	return a.ptr == b.ptr && a.tag == b.tag;
}

/**
 * Enqueue operation, pushes element to queue.
 * @param q pointer to queue struct
 * @param v value to push
 **/
void gq_enqueue(struct gq_t *q, void *v)
{
	TAGGED_PTR(tail);
	TAGGED_PTR(next);
	struct gq_e_t *nd = calloc(sizeof(*nd), 1);
	nd->data = v;
	struct gq_tagged_ptr tmp = atomic_load(&nd->next);
	tmp.ptr = NULL;
	atomic_store(&nd->next, tmp);
	while (1) {
		tail = atomic_load(&q->tail);
		next = atomic_load(&tail.ptr->next);
		if (_gq_pointers_equal(tail, atomic_load(&q->tail))) {
			if (next.ptr == NULL) {
				TAGGED_PTR(new) = { .ptr = nd, .tag = next.tag + 1 };
				if (atomic_compare_exchange_strong(&tail.ptr->next, &next, new)) {
					break;
				}
			} else {
				TAGGED_PTR(new) = { .ptr = next.ptr, .tag = tail.tag + 1 };
				atomic_compare_exchange_strong(&q->tail, &tail, new);
			}
		}

	}
	TAGGED_PTR(n) = { .ptr = nd, .tag = tail.tag + 1 };
	atomic_compare_exchange_strong(&q->tail, &tail, n);
}

/**
 * Dequeue pops the "oldest" element in FIFO order.
 * @param q pointer to queue struct.
 * @return pointer to element, or NULL if empty
 **/
void *gq_dequeue(struct gq_t *q)
{
	TAGGED_PTR(head);
	TAGGED_PTR(tail);
	TAGGED_PTR(next);
	void *data;
	while (1) {
		head = atomic_load(&q->head);
		tail = atomic_load(&q->tail);
		next = head.ptr->next;
		if (_gq_pointers_equal(head, atomic_load(&q->head))) {
			if (head.ptr == tail.ptr) {
				if (next.ptr == NULL) {
					return NULL;
				}
				TAGGED_PTR(new) = { .ptr = next.ptr, tail.tag + 1 };
				atomic_compare_exchange_strong(&q->tail, &tail, new);
			} else {
				data = next.ptr->data;
				TAGGED_PTR(new) = { .ptr = next.ptr, head.tag + 1 };
				if (atomic_compare_exchange_strong(&q->head, &head, new))
					break;

			}
		}
	}
	free(head.ptr);
	return data;
}
/** @} **/


/** @defgroup init Intialization
 *  @{
 **/

/**
 * Initializes a queue.
 * @return pointer to queue struct or NULL on error
 **/
struct gq_t *gq_init(void)
{
	struct gq_t *q = calloc(sizeof(*q), 1);
	struct gq_e_t *nd = calloc(sizeof(*nd), 1);
	struct gq_tagged_ptr tmp = atomic_load(&nd->next);
	tmp.ptr = NULL;
	atomic_store(&nd->next, tmp);
	TAGGED_PTR(dummy) = { .ptr = nd, .tag = 0 };
	atomic_store(&q->tail, dummy);
	atomic_store(&q->head, dummy);
	return q;
}

/**
 * Destroys a queue and frees its backing memory.
 * Note: Does not currently free the memory for its elements!
 * @param q pointer to queue struct
 **/
void gq_destroy(struct gq_t *q)
{
	while(gq_dequeue(q));
	struct gq_tagged_ptr tmp = atomic_load(&q->head);
	free(tmp.ptr);
	free(q);
}

/** @} **/
