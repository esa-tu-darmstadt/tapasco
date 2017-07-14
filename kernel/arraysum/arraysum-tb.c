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
//! @file	arraysum-tb.c
//! @brief	Testbench for kernel arraysum.
//! @authors	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "arraysum.h"

int main(int argc, char **argv)
{
	int data[SZ], i;
	for (i = 0; i < SZ; ++i)
		data[i] = i - (SZ >> 1);

	const int r = arraysum(data);

	printf("Sum = %d (expected: -128)\n", r);
	if (r != -128)
		fprintf(stderr, "FAILURE: wrong result %d\n", r);
	else
		printf("SUCCESS!\n");
	return r == -128 ? EXIT_SUCCESS : EXIT_FAILURE;
}
