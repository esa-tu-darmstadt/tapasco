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
#include "buddy_allocator.hpp"

buddy_allocator::buddy_allocator(uint32_t _address, uint_fast32_t _size, uint_fast32_t _min_order, uint_fast32_t _max_order){

	log(logDEBUG2) << "Calculate init values for buddy_tree";

	min_order = _min_order;
	max_order = _max_order;

	uint32_t address = calc_Address(_address);
	uint_fast32_t size = calc_Size(_size, address - _address);

	log(logDEBUG2) << "Set init values for buddy_tree (size: " << size << ") vs. " << calc_Size(_size, address - _address);
	bt = new buddy_tree(address,size);

	//bt->print_Tree(bt->get_Root());

	if(!check_Tree(bt->get_Root())) {
		build_Tree(bt->get_Root());
		error = 0;
	} else {
		log(logWARNING) << "Tree could not be built completely";
		error = -EINVAL;
	}

	//bt->print_Tree(bt->get_Root());

}

buddy_allocator::~buddy_allocator() {

	log(logDEBUG2) << "Delete buddy_tree";
	delete(bt);
}

void buddy_allocator::print_Tree(void) {
	bt->print_Tree(bt->get_Root());
}

uint_fast32_t buddy_allocator::dealloc_Mem(uint32_t address) {

	if(error)
		return -EINVAL;

	node_t *n = find_Node(address);

	if(!n) {
		log(logWARNING) << "Node for address " << hex << address << " not found" << dec;
		return -EINVAL;
	}
	//bt->print_Node(n);
	node_t *sibling = find_Sibling(n);

	if(bt->dealloc_Leaf(n)) {
		log(logWARNING) << "Failure in deallocation";
		return -EINVAL;
	}

	while(sibling && sibling->usage == nodeFree && n->size < (uint_fast32_t)(1 << max_order)) {
		log(logDEBUG2) << "can merge nodes";
		node_t *parent = n->parent;
		if(bt->merge_Node(parent)) {
			log(logWARNING) << "Merging gone wrong";
		}

		n = parent;
		sibling = find_Sibling(n);
	}

	return 0;
}


node_t * buddy_allocator::find_Sibling(node_t * n) {

	if(n->parent) {
		if(n->parent->l_child == n)
			return n->parent->r_child;
		else //if{n->parent->r_child == n)
			return n->parent->l_child;
	} else {
		log(logDEBUG2) << "Seems to be root - no sibling";
		return NULL;
	}
}


node_t * buddy_allocator::find_Node(uint32_t address) {

	node_t *n = bt->get_Root();
	log(logDEBUG2) << "Search node with matching address " << hex << address << dec;

	//bt->print_Node(n);
	while(n != NULL && (n->usage != nodeAlloc || n->address != address)) {
		n = bt->search_Node(n, address);
		//bt->print_Node(n);
	}

	return n;
}

uint32_t buddy_allocator::alloc_Mem(uint_fast32_t _size) {

	if(error)
		return 0;

	uint_fast32_t size = fit_Order(_size);
	if(!size) {
		log(logINFO) << "Can't find matching order";
		return 0;
	}

	node_t *n = find_Free(size);
	if(!n) {
		log(logINFO) << "Can't find matching node";
		return 0;
	}
	//bt->print_Node(n);

	n = split_Till_Fit(n, size);
	//bt->print_Node(n);

	if(bt->alloc_Leaf(n)) {
		log(logWARNING) << "Allocation gone wrong";
		return 0;
	}

	//bt->print_Tree(bt->get_Root());

	return n->address;
}

node_t * buddy_allocator::split_Till_Fit(node_t *_n, uint_fast32_t size) {

	node_t *n = _n;

	while(n->size > size) {

		if(!bt->split_Node(n)) {
			n = n->l_child;
		} else {
			log(logWARNING) << "Splitting gone wrong";
		}	
	}

	return n;
}

node_t * buddy_allocator::find_Free(uint_fast32_t size) {

	node_t *n = bt->get_Root();
	bt->init_Search();

	log(logDEBUG2) << "Search node with size >= " << size;

	//bt->print_Node(n);
	while(n != NULL && (n->usage != nodeFree || n->size < size)) {
		n = bt->search_Node(n);
		//bt->print_Node(n);
	}

	return n;
}

uint_fast32_t buddy_allocator::fit_Order(uint_fast32_t _size) {

	log(logDEBUG2) << "Check if size smaller than max";
	if(_size > (uint_fast32_t)(1 << max_order)) {
		log(logWARNING) << "Requested size (" << _size << ") too large (" << (1 << max_order) << ")";
		return 0;
	}
	if(_size == 0) {
		log(logWARNING) << "Zero memory request";
		return 0;
	}

	uint_fast32_t size = 1;

	while(size < _size) {
		size = size << 1;
	}

	if(size < (uint_fast32_t)(1 << min_order)) {
		size = 1 << min_order;
	}

	log(logDEBUG2) << "New Size: " << size;

	return size;

}

uint_fast32_t buddy_allocator::build_Tree(node_t *n) {

	if(n->size > (uint_fast32_t)(1 << max_order)) {
		log(logDEBUG1) << "Has to be split";

		if(!bt->split_Node(n)) {
			log(logDEBUG2) << "success - do it recursivly";
			build_Tree(n->l_child);
			build_Tree(n->r_child);
		} else
			log(logWARNING) << "something went wrong";
	}

	return 0;
}

uint_fast32_t buddy_allocator::check_Tree(node_t *n) {

	log(logDEBUG2) << "Check if address wraparounds with size offset";
	if(n->size + n->address < n->address) {
		log(logERROR) << "Size is too large for address";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check min and max order values";
	if(max_order < min_order) {
		log(logERROR) << "Min_Order larger than Max_Order";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check min and max order values upper bounds";
	if(min_order > 31 || max_order > 31) {
		log(logERROR) << "Orders too large for 32 bit space";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check min and max order values under bounds";
	if(min_order == 0 || max_order == 0) {
		log(logERROR) << "Order is Zero";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check if at least one chunk can be built";
	if(n->size < (uint_fast32_t)(1 << min_order)) {
		log(logERROR) << "Size too small for requested Min_Order";
		return -EINVAL;
	}

	return 0;
}

uint32_t buddy_allocator::calc_Address(uint32_t a) {

	if((a & (ALIGNMENT-1)) != 0) {
		log(logDEBUG2) << hex << (a & ~(ALIGNMENT-1)) + ALIGNMENT  << dec;
		return (a & ~(ALIGNMENT-1)) + ALIGNMENT;
	} else {
		log(logDEBUG2) << "Already meets alignment";
		return a;
	}
}

uint_fast32_t buddy_allocator::calc_Size(uint_fast32_t s, uint32_t diff) {

	log(logDEBUG2) << dec << "Old Size: " << s << " Diff: " << diff;

	uint_fast32_t order = 1;
	uint_fast32_t size = s - diff;

	while(order <= size) {
		order = order << 1;
	}

	if(size == 0 || order == 1) {
		log(logWARNING) << " No bytes left for Allocator";
	}

	return order >> 1;
}
