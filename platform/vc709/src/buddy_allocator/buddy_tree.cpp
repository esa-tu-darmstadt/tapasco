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
#include "buddy_tree.hpp"

buddy_tree::buddy_tree(uint32_t _address, uint_fast32_t _size){

	log(logDEBUG2) << "Set init values for root (size: " << _size << ")";
	root = new node_t(_address,_size,NULL);

	search_last = NULL;
	search_direction = nodeLeft;
	nodes = leaves = 1;
}

buddy_tree::~buddy_tree() {

	log(logDEBUG2) << "Delete root node";
	delete(root);
}

uint_fast32_t buddy_tree::split_Node(node_t *n) {

	log(logDEBUG2) << "Check if it has any childs";
	if(n->l_child != NULL || n->r_child != NULL) {
		// redundant check, if node->usage is correctly used
		log(logERROR) << "Contains childs - stop";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check if it is really free";
	if(n->usage != nodeFree) {
		log(logERROR) << "In use - stop";
		return -EINVAL;
	}

	n->l_child = new node_t(n->address,n->size/2,n);
	n->r_child = new node_t(n->address+n->size/2,n->size/2,n);

	n->usage = nodeMiddle;

	nodes += 2;
	leaves++;

	log(logDEBUG1) << "Count nodes: " << nodes << " leaves: " << leaves;

	return 0;	
}

uint_fast32_t buddy_tree::merge_Node(node_t *n) {

	log(logDEBUG2) << "Check if it has any childs";
	if(n->l_child == NULL || n->r_child == NULL) {
		// redundant check, if node->usage is correctly used
		log(logERROR) << "Contains no childs - stop";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check if childs are free";
	if(n->l_child->usage != nodeFree || n->r_child->usage != nodeFree) {
		log(logERROR) << "In use - stop";
		return -EINVAL;
	}

	delete(n->l_child);
	delete(n->r_child);
	n->l_child = n->r_child = NULL;

	n->usage = nodeFree;

	nodes -= 2;
	leaves--;

	log(logDEBUG1) << "Count nodes: " << nodes << " leaves: " << leaves;

	return 0;	
}

void buddy_tree::init_Search(void) {
		search_last = NULL;
		search_direction = nodeLeft;
}

node_t * buddy_tree::search_Node(node_t *n) {

	if(has_Childs(n) && search_direction == nodeLeft) {
		return n->l_child;
	}
	else if(has_Childs(n) && search_last != n->r_child) {
		search_direction = nodeLeft;
		return n->r_child;
	}
	else if(!is_Root(n)) {
		search_last = n;
		search_direction = nodeRight;
		return n->parent;
	}
	else {
		return NULL;
	}
}

node_t * buddy_tree::search_Node(node_t *n, uint32_t address) {

	if(has_Childs(n) && address < n->r_child->address) {
		return n->l_child;
	}
	else if(has_Childs(n)) {
		return n->r_child;
	}
	else {
		return NULL;
	}
}

void buddy_tree::print_Tree(node_t *n) {

	node_t *last = NULL;
	node_t *current = n;
	node_position_e direction = nodeLeft;

	uint_fast32_t depth = 0;

	log(logINFO) << "Count nodes: " << nodes << " leaves: " << leaves;
	print_Node(current);

	while(current != NULL) {
		log(logDEBUG3) << "Current: " << hex << current << " Last: " << last << dec << " Depth: " << depth;

		if(has_Childs(current) && direction == nodeLeft) {
			depth++;
			current = current->l_child;
			print_Node(current);
		}
		else if(has_Childs(current) && last != current->r_child) {
			depth++;
			current = current->r_child;
			print_Node(current);
			direction = nodeLeft;
		}
		else if(!is_Root(current)) {
			depth--;
			last = current;
			current = current->parent;
			direction = nodeRight;
		}
		else {
			current = NULL;
		}	
	}
}

void buddy_tree::print_Node(node_t *n) {

	string s;

	switch(n->usage) {
		case nodeFree:
			s = " usage: nodeFree";
			break;
		case nodeAlloc:
			s = " usage: nodeAlloc";
			break;
		case nodeMiddle:
			s = " usage: nodeMiddle";
			break;
		default:
			s = " no supported usage";
	}

	if(n->usage != nodeMiddle) {
		log(logDEBUG) << "Address: " << hex << n->address << dec
		<< " Size: " << n->size
		<< s;
	} else {
		log(logDEBUG1) << "Address: " << hex << n->address << dec
		<< " Size: " << n->size
		<< s;
	}
}

node_position_e buddy_tree::node_Position(node_t *n) {

	if(n->parent == NULL)
		return nodeRoot;
	else if(n->parent->l_child == n)
		return nodeLeft;
	else
		return nodeRight;
}

bool buddy_tree::is_Root(node_t *n) {

	if(n->parent == NULL)
		return true;
	else
		return false;
}

bool buddy_tree::has_Childs(node_t *n) {

	if(n->l_child != NULL && n->r_child != NULL)
		return true;
	else
		return false;
}

bool buddy_tree::is_Leaf(node_t *n) {

	if(n->l_child == NULL && n->r_child == NULL)
		return true;
	else
		return false;
}

uint_fast32_t buddy_tree::alloc_Leaf(node_t *n) {

	log(logDEBUG2) << "Check if it really is a leaf";
	if(!is_Leaf(n)) {
		// redundant check, if node->usage is correctly used
		log(logERROR) << "Node is no leaf - stop";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check if is really free";
	if(n->usage != nodeFree) {
		log(logERROR) << "In use - stop";
		return -EINVAL;
	}

	n->usage = nodeAlloc;

	return 0;
}

uint_fast32_t buddy_tree::dealloc_Leaf(node_t *n) {

	log(logDEBUG2) << "Check if it really is a leaf";
	if(!is_Leaf(n)) {
		// redundant check, if node->usage is correctly used
		log(logERROR) << "Node is no leaf - stop";
		return -EINVAL;
	}

	log(logDEBUG2) << "Check if is really allocated";
	if(n->usage != nodeAlloc) {
		log(logERROR) << "Not used - stop";
		return -EINVAL;
	}

	n->usage = nodeFree;

	return 0;
}

node_t * buddy_tree::get_Root(void) {

	log(logDEBUG2) << "Return root for tree operations";
	return root;
}
