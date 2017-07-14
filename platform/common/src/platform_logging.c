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
//! @file	platform_logging.c
//! @brief	Logging helper implementation. Initialization for debug output.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <limits.h>
#include <pthread.h>
#include <assert.h>
#include <time.h>
#include <sys/syscall.h>
#include <sys/types.h>

#include "platform_logging.h"
#include "gen_queue.h"
#include "gen_stack.h"

#ifndef NDEBUG
static unsigned long int libplatform_logging_level = ULONG_MAX;
static FILE *libplatform_logging_file = NULL;

static struct gq_t *log_q;
static volatile bool exiting = false;
static pthread_t log_thread;
static struct gs_t log_s;

#define LOG_MSG_S_SZ						4096
struct log_msg_t {
	char msg[256];
	platform_ll_t lvl;
	struct timespec tv;
	pid_t tid;
};

static inline struct log_msg_t *get_msg()
{
	struct log_msg_t *msg = (struct log_msg_t *) gs_pop(&log_s);
	if (! msg) msg = malloc(sizeof(*msg));
	assert(msg);
	return msg;
}

void platform_log(platform_ll_t const level, char *fmt, ...)
{
	if (!level || (level & libplatform_logging_level)) {
		struct log_msg_t *lm = get_msg();
		clock_gettime(CLOCK_MONOTONIC, &lm->tv);
		va_list ap;
		va_start(ap, fmt);
		vsnprintf(lm->msg, sizeof(lm->msg) - 1, fmt, ap);
		va_end(ap);
		lm->lvl = level;
		lm->tid = syscall(SYS_gettid);
		gq_enqueue(log_q, lm);
	}
}

static inline void handle_msg(struct log_msg_t *m)
{
	fprintf(libplatform_logging_file ? libplatform_logging_file : stderr, 
		m->lvl ? (m->lvl ^ 1 ?
			"%lld\t%d\t[libplatform - info]\t%s" :
			"%lld\t%d\t[libplatform - warning]\t%s") :
			"%lld\t%d\t[libplatform - error]\t%s",
		m->tv.tv_sec * 1000000000LL + m->tv.tv_nsec, m->tid, m->msg);
	gs_push(&log_s, m);
}

static void *log_thread_main(void *p)
{
	struct gq_t *q = (struct gq_t *)p;
	void *lm;
	while (! exiting) {
		unsigned long n = 10;
		while (n-- && (lm = gq_dequeue(q)))
			handle_msg((struct log_msg_t *) lm);
		usleep(1000000);
	}
	// flush the queue
	while ((lm = gq_dequeue(q)))
		handle_msg((struct log_msg_t *) lm);
	return NULL;
}

int platform_logging_init(void)
{
	static int is_initialized = 0;
	if (! is_initialized) {
		char const *dbg = getenv("LIBPLATFORM_DEBUG");
		char const *lgf = getenv("LIBPLATFORM_LOGFILE");
		libplatform_logging_level = dbg ? (strtoul(dbg, NULL, 0) | 0x1) : ULONG_MAX;
		libplatform_logging_file = lgf ? fopen(lgf, "w+") : stderr;
		if (! libplatform_logging_file) {
			libplatform_logging_file = stderr;
			WRN("could not open logfile '%s'!\n", lgf);
		}

		log_q = gq_init();
		assert(log_q || "could not allocate log queue: out-of-memory");
		for (int i = 0; i < LOG_MSG_S_SZ; ++i) {
			void *msg = malloc(sizeof(struct log_msg_t));
			assert (msg);
			gs_push(&log_s, msg);
		}
		if (pthread_create(&log_thread, NULL, log_thread_main, log_q))
			ERR("could not create the logging thread");
	}
	return 1;
}

void platform_logging_exit(void)
{
	struct log_msg_t *lm;
	exiting = true;
	if (log_thread) pthread_join(log_thread, NULL);
	gq_destroy(log_q);
	while ((lm = (struct log_msg_t *) gs_pop(&log_s)))
		free(lm);

	if (libplatform_logging_file != stderr) {
		fflush(libplatform_logging_file);
		fclose(libplatform_logging_file);
	}
	libplatform_logging_file = NULL;
}
#else  // NDEBUG
int platform_logging_init(void) { return 1; }
void platform_logging_exit(void) {}
#endif // NDEBUG
