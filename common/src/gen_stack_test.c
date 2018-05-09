#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <stdatomic.h>
#include <stdint.h>
#include <limits.h>
#include "gen_stack.h"

static
struct gs_t _stk;

static
_Atomic int64_t _exe = 1LL << 24;

void *run(void *arg)
{
	while (atomic_fetch_sub(&_exe, 1LL) > 0) {
		gs_push(&_stk, arg);
		gs_pop(&_stk);
	}
	return NULL;
}

int main(int argc, char *argv[])
{
	size_t num_threads = sysconf(_SC_NPROCESSORS_ONLN);
	if (argc > 1)
		num_threads = strtoul(argv[1], NULL, 0);
	pthread_t threads[num_threads];

	for (size_t i = 0; i < num_threads; ++i) {
		pthread_create(&threads[i], NULL, run, (void *)(i + 1));
	}

	for (size_t i = 0; i < num_threads; ++i) {
		pthread_join(threads[i], NULL);
	}
}
