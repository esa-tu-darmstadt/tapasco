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
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <pthread.h>

#define UPPER_BND					(25)

static char const *const fn[] = {
	"/sys/class/misc/tapasco_platform_zynq_gp0/alloc",
	"/sys/class/misc/tapasco_platform_zynq_gp0/dealloc",
	"/sys/class/misc/tapasco_platform_zynq_gp0/bufferid",
};
static int fd[sizeof(fn) / sizeof(*fn)] = { -1 };
static int stop = 0;

void *stress(void *p)
{	
	ssize_t res, dma;
	unsigned long runs = (unsigned long)p;
	printf("Starting %lu runs ...\n", runs);
	while (runs && ! stop) {
		size_t const sz = pow(2, (rand() % UPPER_BND));
		dma = write(fd[0], &sz, sizeof(sz));
		if (dma < 0) {
			stop = 1;
			fprintf(stderr, "error during allocation of size 0x%zu byte: %s\n",
					sz, strerror(errno));
			return NULL;
		}
		usleep(rand() % 1000);
		res = write(fd[2], &res, sizeof(res));
		if (res < 0) {
			stop = 1;
			fprintf(stderr, "could not find buffer for address 0x%08lx: %s\n",
					sz, (unsigned long)dma, strerror(errno));
			return NULL;
		}
		usleep(rand() % 1000);
		res = write(fd[1], &dma, sizeof(dma));
		if (res < 0) {
			stop = 1;
			fprintf(stderr, "could not deallocate 0x%08lx: %s\n",
					(unsigned long)dma, strerror(errno));
			return NULL;
		}
		--runs;
	}
	return NULL;
}

int main(int argc, char **argv)
{
	int i, t;
	long const thread_count = argc > 1 ? strtol(argv[1], NULL, 0) : sysconf(_SC_NPROCESSORS_CONF);
	unsigned long const runs = argc > 2 ? strtoul(argv[2], NULL, 0) : 10000;
	pthread_t threads[thread_count];

	srand(time(NULL));

	for (i = 0; i < sizeof(fn) / sizeof(*fn); ++i) {
		fd[i] = open(fn[i], O_WRONLY);
		if (fd[i] == -1) {
			fprintf(stderr, "could not open %s: %s\n", fn[i], strerror(errno));
			while (i >= 0)
				close(fd[--i]);
			exit(EXIT_FAILURE);
		}
	}

	printf("Starting %ld threads ...\n", thread_count);
	for (t = 0; t < thread_count; ++t)
		pthread_create(&threads[t], NULL, stress, (void *)runs);
	for (t = 0; t < thread_count; ++t)
		pthread_join(threads[t], NULL);

	while (i >= 0)
		close(fd[--i]);

	if (! stop)
		printf("Test successful.\n");
	else
		fprintf(stderr, "Test failed!\n");
	return stop ? EXIT_FAILURE : EXIT_SUCCESS;
}
