//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
#ifndef __BUDDY_ALLOCATOR_HPP_
#define __BUDDY_ALLOCATOR_HPP_

#include "buddy_tree.hpp"
#include "logger.hpp"

//#define MIN_ORDER 12 // 12 == 4 KB
//#define MAX_ORDER 13 // 22 == 4 MB

#define ALIGNMENT 8

using namespace std;

class buddy_allocator
{
	public:
		buddy_allocator(uint32_t, uint_fast32_t, uint_fast32_t, uint_fast32_t);
		~buddy_allocator();

		uint32_t alloc_Mem(uint_fast32_t);
		uint_fast32_t dealloc_Mem(uint32_t);

		void print_Tree(void);

	private:
		buddy_tree *bt;
		uint_fast32_t min_order;
		uint_fast32_t max_order;

		uint_fast32_t error;

		uint32_t calc_Address(uint32_t);
		uint_fast32_t calc_Size(uint_fast32_t, uint32_t);
		uint_fast32_t build_Tree(node_t *);
		uint_fast32_t check_Tree(node_t *);

		node_t * find_Free(uint_fast32_t);
		node_t * find_Node(uint32_t);
		node_t * find_Sibling(node_t *);
		uint_fast32_t fit_Order(uint_fast32_t);
		node_t * split_Till_Fit(node_t *, uint_fast32_t);

};

#endif // __BUDDY_ALLOCATOR_HPP_
