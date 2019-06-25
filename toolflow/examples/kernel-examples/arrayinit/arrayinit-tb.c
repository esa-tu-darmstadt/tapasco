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
//! @file arrayinit-tb.c
//! @brief Testbench code for the arrayinit kernel.
//! @authors J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "arrayinit.h"

int main(int argc, char **argv)
{
	int *data = (int *)calloc(SZ, sizeof(int));
	int i, ret = 0;
	arrayinit(data);

	for (i = 0; i < SZ; ++i) {
		ret += data[i] == i ? 0 : 1;
		if (data[i] != i) 
			fprintf(stderr, "data[%d] is wrong: %d\n", i, data[i]);
	}

	free(data);
	if (ret)
		fprintf(stderr, "FAILURE\n");
	else
		printf("SUCCESS!\n");
	return ! ret ? EXIT_SUCCESS : EXIT_FAILURE;
}
