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
/* some common routines */
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include "common.h"

void dump_file(const char *fn, char *data, const size_t sz) {
	int fd = open(fn, O_CREAT | O_TRUNC | O_WRONLY,
			S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP |
			S_IROTH | S_IWOTH);
	if (fd <= 0)
		fprintf(stderr, "could not write to %s: %s\n",
				fn, strerror(errno));
	assert(fd > 0);
	size_t n = 0;
	while (n < sz) {
		ssize_t status = write(fd, data, sz - n);
		if (status < 0)
			fprintf(stderr, "could not write to %s: %s\n",
					fn, strerror(errno));
		assert(status >= 0);
		n += status;
	}
	close(fd);
	printf("dumped %zd byte to %s.\n", sz, fn);
}

