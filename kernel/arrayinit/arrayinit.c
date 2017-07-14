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
//! @file	arrayinit.h
//! @brief 	Trivial kernel: Initializes an array of size SZ to consecutive 
//! 		element index numbers.
//! @authors 	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#include "arrayinit.h"

int arrayinit(int arr[SZ])
{
	int i = 0;
	for (; i < SZ; ++i)
		arr[i] = i;
	return 42;
}

