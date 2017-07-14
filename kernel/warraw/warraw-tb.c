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
//! @file	warraw.c
//! @brief	Testbench code for warraw kernel,
//! @authors	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "warraw.h"

int main(int argc, char **argv)
{
	int data[SZ], i, ret = 0, s = 0;
	for (i = 0; i < SZ; ++i)
		data[i] = i + 1;

	s = warraw(data);

	for (i = 0; i < SZ; ++i) {
		ret += data[i] == 42 + i + 1 ? 0 : 1;
		if (data[i] != 42 + i + 1) 
			fprintf(stderr, "data[%d] is wrong: %d\n", i, data[i]);
	}
	// result should be: 256 * 256 + 256 + 42 * 256 = 76544
	ret += s == 76544 ? 0 : 1000;
	printf("s = %d\n", s);
	if (ret)
		fprintf(stderr, "FAILURE\n");
	else
		printf("SUCCESS!\n");
	return ret ? EXIT_FAILURE : EXIT_SUCCESS;
}
