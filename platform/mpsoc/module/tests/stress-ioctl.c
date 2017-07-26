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
/**
 *  @file	stress-ioctl.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <assert.h>
#include <pthread.h>
#include <ncurses.h>
#include <sys/ioctl.h>
#include <sched.h>
#include <zynq_ioctl_cmds.h>

static int fd_ioctl = -1;
static long thrdcnt = 0;
static volatile int stop = 0;
static volatile int finish = 0;
static volatile long runs = 0;
static volatile unsigned long long alloced_bytes = 0ULL;
static volatile unsigned long long freed_bytes   = 0ULL;
static volatile unsigned long long copyto_bytes = 0ULL;
static volatile unsigned long long copyfrom_bytes = 0ULL;
static volatile long errors = 0;
static volatile long terrors = 0;

static inline void random_fill(void *p, size_t const len)
{
	FILE *fd = fopen("/dev/urandom", "r");
	assert(fd);
	fread(p, 1, len, fd);
	fclose(fd);
}

static inline void print_cmd(volatile struct zynq_ioctl_cmd_t *c)
{
	printf("data = 0x%08x, length = %zu, id = %ld, dma = 0x%08x\n",
			(unsigned long) c->data, c->length, c->id, c->dma_addr);
}

static inline void copy_check(size_t const *lp)
{
	volatile struct zynq_ioctl_cmd_t cmd;
	size_t const sz = lp ? *lp : rand() % (1 << 20) & ~0x3;
	unsigned char *data1 = malloc(sz);
	unsigned char *data2 = malloc(sz);
	assert(data1); assert(data2);

	memset((void *)&cmd, 0, sizeof(cmd));
	random_fill(data1, sz);

	cmd.data = data1;
	cmd.length = sz;
	cmd.id = -1;
	if (! ioctl(fd_ioctl, ZYNQ_IOCTL_COPYTO, &cmd)) {
		__atomic_fetch_add(&alloced_bytes, sz, __ATOMIC_SEQ_CST);
		__atomic_fetch_add(&copyto_bytes, sz, __ATOMIC_SEQ_CST);
		cmd.data = data2;
		if (! ioctl(fd_ioctl, ZYNQ_IOCTL_COPYFREE, &cmd)) {
			__atomic_fetch_add(&freed_bytes, sz, __ATOMIC_SEQ_CST);
			__atomic_fetch_add(&copyfrom_bytes, sz, __ATOMIC_SEQ_CST);
		} else
			__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
	} else __atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);

	if (memcmp(data1, data2, sz) != 0)
		__atomic_fetch_add(&terrors, 1, __ATOMIC_SEQ_CST);

	free(data1);
	free(data2);
}

static inline void alloc_free(size_t const *lp)
{
	volatile struct zynq_ioctl_cmd_t cmd;
	size_t sz = lp ? *lp : rand() % (1 << 20) & ~0x3;
	memset((void *)&cmd, 0, sizeof(cmd));
	cmd.id = -1;
	cmd.length = sz;
	if (! ioctl(fd_ioctl, ZYNQ_IOCTL_ALLOC, &cmd)) {
		__atomic_fetch_add(&alloced_bytes, sz, __ATOMIC_SEQ_CST);
		if (ioctl(fd_ioctl, ZYNQ_IOCTL_FREE, &cmd))
			__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
		else
			__atomic_fetch_add(&freed_bytes, sz, __ATOMIC_SEQ_CST);
	} else __atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
}

static void *stress(void *p)
{
	long const which = (long) p;
	while (! finish) {
		switch (which) {
		case 1: alloc_free(NULL); break;
		case 2: copy_check(NULL); break;
		default: stop = 1; return NULL;
		}
		__atomic_fetch_add(&runs, 1, __ATOMIC_SEQ_CST);
		sched_yield();
	}
	return NULL;
}

static void init_ncurses()
{
	initscr();
	noecho();
	cbreak();
	curs_set(0);
	timeout(0);
}

static void exit_ncurses()
{
	endwin();
}

static int runtest(long const which)
{
	const char *const stre = "--- press any key to exit ---";
	struct timespec tv_begin, tv_now;
	pthread_t threads[thrdcnt];
	char str[255];
	int rows, cols;

	getmaxyx(stdscr, rows, cols);

	fd_ioctl = open("/dev/" ZYNQ_IOCTL_FN, O_RDONLY);
	if (fd_ioctl == -1) {
		exit_ncurses();
		fprintf(stderr, "could not open /dev/%s: %s\n", ZYNQ_IOCTL_FN,
				strerror(errno));
		exit(EXIT_FAILURE);
	}

	clear();
	mvprintw(rows / 2, (cols - strlen(stre)) / 2, stre);


	clock_gettime(CLOCK_MONOTONIC, &tv_begin);

	for (long t = 0; t < thrdcnt; ++t)
		pthread_create(&threads[t], NULL, stress, (void *)which);

	while (getch() == ERR) {
		int r = rows / 3 - 3;
		snprintf(str, 255, "     Passes: %16lu runs ", runs);
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		snprintf(str, 255, "     Errors: %16lu      ", errors);
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		snprintf(str, 255, "   T-Errors: %16lu      ", terrors);
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		snprintf(str, 255, "   Alloc'ed: %16llu bytes", alloced_bytes);
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		snprintf(str, 255, "     Free'd: %16llu bytes", freed_bytes);
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		snprintf(str, 255, "  CopyTo'ed: %16llu bytes", copyto_bytes);
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		snprintf(str, 255, "CopyFrom'ed: %16llu bytes", copyfrom_bytes);
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		clock_gettime(CLOCK_MONOTONIC, &tv_now);
		snprintf(str, 255, "    SpeedTo: %16.2f KiB/s", 
				(copyto_bytes >> 10) / (double)
					(tv_now.tv_sec - tv_begin.tv_sec));
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		snprintf(str, 255, "  SpeedFrom: %16.2f KiB/s", 
				(copyfrom_bytes >> 10) / (double)
					(tv_now.tv_sec - tv_begin.tv_sec));
		mvprintw(r++, (cols - strlen(str)) / 2, str);
		refresh;
	}
	finish = 1;

	for (long t = 0; t < thrdcnt; ++t)
		pthread_join(threads[t], NULL);

	close(fd_ioctl);
}

static int menu(long const thrdcnt)
{
	int rows, cols, r, c;
	const char *const strwelcome = "Welcome to Zynq ioctl Test! Choose Test:";
	const char *const strc1 = "1) alloc-free (multi-threaded)";
	const char *const strc2 = "2) copyto-copyfree (multi-threaded)";
	const char *const strcq = "--- any other key to exit ---";
	char strparams[255];
	const int off = strlen(strc2);
	getmaxyx(stdscr, rows, cols);
	r = rows / 3;
	mvprintw(r++, (cols - strlen(strwelcome)) / 2, strwelcome);
	r += 2;
	mvprintw(r++, (cols - off) / 2, strc1);
	mvprintw(r++, (cols - off) / 2, strc2);
	r += 1;
	mvprintw(r++, (cols - strlen(strcq)) / 2, strcq);

	r += 2;
	snprintf(strparams, 255, "Threads: %u", thrdcnt);
	mvprintw(r, (cols - strlen(strparams)) / 2, strparams);

	while ((c = getch()) == ERR);
	if (c == '1' || c == '2')
		runtest(c == '1' ? 1 : 2);
	return c;
}

static void print_summary()
{
	printf( "Passes   : %16lu runs\n"
			"Errors   : %16lu\n"
			"T-Errors : %16lu\n"
			"Allocated: %16llu bytes\n"
			"Freed    : %16llu bytes\n"
			"CopyTo   : %16llu bytes\n"
			"CopyFrom : %16llu bytes\n",
			runs, errors, terrors, alloced_bytes, freed_bytes,
			copyto_bytes, copyfrom_bytes);
}

int main(int argc, char *argv[])
{
	int i, t;
	thrdcnt = argc > 1 ? strtol(argv[1], NULL, 0) : sysconf(_SC_NPROCESSORS_CONF);

	srand(time(NULL));

	init_ncurses();
	menu(thrdcnt);
	exit_ncurses();

	print_summary();

	if (! stop)
		printf("Test successful.\n");
	else
		fprintf(stderr, "Test failed!\n");
	return stop ? EXIT_FAILURE : EXIT_SUCCESS;
}
/* vim: set foldmarker=@{,}@ foldlevel=0 foldmethod=marker : */
