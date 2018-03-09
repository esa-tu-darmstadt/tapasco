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
#ifndef __BUDDY_TREE_HPP_
#define __BUDDY_TREE_HPP_

#include <cstdint>
#include <cerrno>

#include "logger.hpp"

using namespace std;

//leafFree 	== can be used for allocation or merging
//leafAlloc == node is allocated, must not use
//leafMiddle == node is neither leaf or allocated, must not use
enum node_usage_e
    {nodeFree, nodeAlloc, nodeMiddle};

enum node_position_e
    {nodeRoot, nodeLeft, nodeRight};

typedef struct node {

  uint32_t address;
  uint_fast32_t size;

  node_usage_e usage;

  struct node *parent;
  struct node *l_child;
  struct node *r_child;

  node(uint32_t a, uint_fast32_t s, struct node *p) : address(a), size(s), usage(nodeFree), parent(p), l_child(NULL), r_child(NULL) {}
  node() : address(0), size(0), usage(nodeFree), parent(NULL), l_child(NULL), r_child(NULL) {}

} node_t;

class buddy_tree
{
	public:
		buddy_tree(uint32_t, uint_fast32_t);
		~buddy_tree();

		uint_fast32_t split_Node(node_t *);
		uint_fast32_t merge_Node(node_t *);
		uint_fast32_t alloc_Leaf(node_t *);
		uint_fast32_t dealloc_Leaf(node_t *);

		void init_Search(void);
		node_t * search_Node(node_t *);
		node_t * search_Node(node_t *, uint32_t);

		node_t * get_Root(void);
		void print_Tree(node_t *);
		void print_Node(node_t *);

	private:
		node_t *root;
		uint_fast32_t nodes;
		uint_fast32_t leaves;

		node_t *search_last;
		node_position_e search_direction;

		node_position_e node_Position(node_t *);
		bool is_Root(node_t *);
		bool is_Leaf(node_t *);
		bool has_Childs(node_t *);
};

#endif // __BUDDY_TREE_HPP_
