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
//! @file	gen_stack.h
//! @brief	Generic, header-only, lock-free implementation of a dynamic
//!		sized pool of things. Note: uses malloc, so not entirely
//!		lock-free (memory locks).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __GEN_STACK_H__
#define __GEN_STACK_H__

#include <stdlib.h>
#ifdef __STDC_NO_ATOMICS__
#error "C compiler does not have atomics"
#endif
#include <stdatomic.h>

#define TAGGED_PTR(VAR) struct gs_tagged_ptr_t VAR __attribute__ ((aligned(16)))

/** 
 * Tagged pointer struct: contains pointer + update counter. 
 * Basic idea: use atomic instructions for full size of struct, in case
 * of x86_64 16 byte, on 32bit archs like armv7 8 byte.
 **/
struct gs_tagged_ptr_t { 
	struct gs_e_t *p __attribute__ ((aligned(16)));
	unsigned long int tc __attribute__ ((packed));
};

/** Stack element type. */
struct gs_e_t {
	struct gs_e_t *next;
	void *data;
};

/** Stack type. */
struct gs_t {
	_Atomic(struct gs_tagged_ptr_t) free;
}; 

/**
 * Pops the top-most element from the stack.
 * @param stack pointer to stack instance.
 * @return void pointer to element data.
 **/
static inline void *gs_pop(struct gs_t *stack) {
	TAGGED_PTR(old);
	volatile TAGGED_PTR(n);
	void *ret = NULL;
	do {	
		old = stack->free;
		n.tc = old.tc + 1;
		if (old.p) {
			ret = old.p->data; 
			n.p = old.p->next;
		} else {
			ret = n.p = NULL;
		}
	} while (! atomic_compare_exchange_strong(&stack->free, &old, n));
	if (ret)
		free(old.p);
	return ret;
}

/**
 * Pushes an element to the top of the stack.
 * @param stack pointer to stack instance.
 * @param elem void pointer ot element data.
 **/
static inline void gs_push(struct gs_t *stack, void *elem) {
	TAGGED_PTR(old);
	TAGGED_PTR(n);
	struct gs_e_t *e = malloc(sizeof(*e));
	e->data = elem;
	do {
		old = stack->free;
		n.tc = old.tc + 1;
		n.p = e;
		e->next = old.p;
	} while (! atomic_compare_exchange_strong(&stack->free, &old, n));
}

#endif /* __GEN_STACK_H__ */
