#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <stdatomic.h>
#include <limits.h>
#include <unistd.h>
#include "gen_queue.h"

#define RUNS		(long)(1L << 22)

static atomic_long jobs = RUNS;
static atomic_bool stop = 0;
static long recv = 0;

void *push_data(void *p)
{
	struct gq_t *q = (struct gq_t *)p;
	long id;
	while ((id = atomic_fetch_sub(&jobs, 1)) > 0) {
		gq_enqueue(q, (void *)id);
	}
	return NULL;
}

void *pop_data(void *p)
{
	struct gq_t *q = (struct gq_t *)p;
	long id;
	while (! stop) {
		while ((id = (long)gq_dequeue(q))) {
			++recv;
		}
		usleep(1000);
	}
	return NULL;
}

int main(int argc, char *argv[])
{
	const long num_cpus = argc > 1 ? strtol(argv[1], NULL, 0) : sysconf(_SC_NPROCESSORS_ONLN) + 1;
	pthread_t threads[num_cpus];
	struct gq_t *q = gq_init();
	printf("Creating %ld threads ...\n", num_cpus);
	pthread_create(&threads[0], NULL, pop_data, q);
	for (size_t i = 1; i < num_cpus; ++i) {
		pthread_create(&threads[i], NULL, push_data, q);
	}
	for (size_t i = 1; i < num_cpus; ++i) {
		pthread_join(threads[i], NULL);
	}
	stop = 1;
	usleep(10000);
	pthread_join(threads[0], NULL);
	printf("recv: %ld, expected: %ld\n", recv, RUNS);
	gq_destroy(q);
	return recv == RUNS ? 0 : 1;
}
