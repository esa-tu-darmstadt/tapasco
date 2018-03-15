/**
 *  @file	tapasco_async_benchmark.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <tapasco_async.h>
#include <tapasco_types.h>
#include <tapasco_logging.h>

#define NUM_JOBS					10000

static tapasco_async_t *a = NULL;

void *wait_for_job(void *p)
{
	tapasco_job_id_t const j_id = (tapasco_job_id_t)p;
	tapasco_async_wait_on_job(a, j_id);
	printf("job #%lu finished!\n", j_id);
	return NULL;
}

void *launch_jobs(void *p)
{
	tapasco_job_id_t const j_id = (tapasco_job_id_t)p;
	size_t num_jobs = NUM_JOBS;
	while (--num_jobs) {
		tapasco_async_enqueue_job(a, j_id);
		tapasco_async_wait_on_job(a, j_id);
		//printf("thread %lu, job %zd finished\n", j_id, num_jobs);
	}
	printf("thread %lu finished!\n", j_id);
	return NULL;
}

int main(int argc, char *argv[])
{
	size_t const num_threads = sysconf(_SC_NPROCESSORS_CONF) - 2L;
	tapasco_logging_init();
	tapasco_res_t r = tapasco_async_init(&a);
	assert(a);

	pthread_t threads[num_threads];

	for (size_t i = 0; i < num_threads; ++i) {
		pthread_create(&threads[i], NULL, launch_jobs, (void *)(i + 1));
	}

	for (size_t i = 0; i < num_threads; ++i) {
		pthread_join(threads[i], NULL);
	}
	printf("all threads joined.\n");

	tapasco_async_deinit(a);
	tapasco_logging_exit();
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
