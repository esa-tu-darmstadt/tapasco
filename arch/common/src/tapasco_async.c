/**
 *  @file	tapasco_async.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <assert.h>
#include <tapasco_async.h>
#include <tapasco.h>
#include <tapasco_errors.h>
#include <tapasco_logging.h>
#include <tapasco_async_dispatcher.h>
#include <tapasco_async_collector.h>

tapasco_res_t tapasco_async_init(tapasco_async_t **pa)
{
	*pa = (tapasco_async_t *)malloc(sizeof(**pa));
	if (! *pa) {
		ERR("could not allocate async");
		return TAPASCO_ERR_OUT_OF_MEMORY;
	}
	LOG(LALL_ASYNC, "initializing %d semaphores ...",
			NUM_SEM);
	for (size_t i = 0; i < NUM_SEM; ++i) {
		sem_init(&(*pa)->job_sem[i], 0, 0);
	}
	LOG(LALL_ASYNC, "initializing launch queue ...");
	(*pa)->launch_q = gq_init();
	LOG(LALL_ASYNC, "initializing finished queue ...");
	(*pa)->finished_q = gq_init();
	LOG(LALL_ASYNC, "starting dispatcher thread ...");
	tapasco_res_t r = tapasco_async_dispatcher_init(*pa);
	if (r != TAPASCO_SUCCESS) {
		ERR("could not initialize dispatcher thread: %s (%d)",
				tapasco_strerror(r), r);
		return r;
	}
	LOG(LALL_ASYNC, "starting collector thread ...");
	r = tapasco_async_collector_init(*pa);
	if (r != TAPASCO_SUCCESS) {
		ERR("could not initialize collector thread: %s (%d)",
				tapasco_strerror(r), r);
		return r;
	}
	LOG(LALL_ASYNC, "async initialized");
	return TAPASCO_SUCCESS;
}

void tapasco_async_deinit(tapasco_async_t *a)
{
	LOG(LALL_ASYNC, "stopping collector thread ...");
	tapasco_async_collector_deinit(a);
	LOG(LALL_ASYNC, "stopping dispatcher thread ...");
	tapasco_async_dispatcher_deinit(a);
	LOG(LALL_ASYNC, "releasing finished queue ...");
	gq_destroy(a->finished_q);
	LOG(LALL_ASYNC, "releasing launch queue ...");
	gq_destroy(a->launch_q);
	LOG(LALL_ASYNC, "deiniting async, releasing %d semaphores",
			NUM_SEM);
	for (size_t i = 0; i < NUM_SEM; ++i) {
		sem_close(&a->job_sem[i]);
	}
	free(a);
	LOG(LALL_ASYNC, "async destroyed");
}

tapasco_res_t tapasco_async_wait_on_job(tapasco_async_t *a,
		tapasco_job_id_t const j_id)
{
	assert (a);
	assert (j_id < NUM_SEM);
	sem_wait(&a->job_sem[j_id]);
	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_async_job_finished(tapasco_async_t *a,
		tapasco_job_id_t const j_id)
{
	assert (a);
	assert (j_id < NUM_SEM);
	sem_post(&a->job_sem[j_id]);
	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_async_enqueue_job(tapasco_async_t *a,
		tapasco_job_id_t const j_id)
{
	assert (a);
	assert (j_id < NUM_SEM);
	gq_enqueue(a->launch_q, (void *)j_id);
	return TAPASCO_SUCCESS;
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
