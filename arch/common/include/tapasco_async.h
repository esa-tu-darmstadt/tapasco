/**
 *  @file	tapasco_async.h
 *  @brief	TaPaSCo synchronous launching support.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TAPASCO_ASYNC_H__
#define TAPASCO_ASYNC_H__

#include <semaphore.h>
#include <pthread.h>
#include <tapasco_types.h>
#include <tapasco_jobs.h>
#include <gen_queue.h>

#define	NUM_SEM				TAPASCO_JOBS_Q_SZ

typedef struct {
	sem_t job_sem[NUM_SEM];
	struct gq_t *launch_q;
	struct gq_t *finished_q;
	pthread_t dispatcher;
	pthread_t collector;
} tapasco_async_t;

tapasco_res_t tapasco_async_init(tapasco_async_t **pa);
void tapasco_async_deinit(tapasco_async_t *a);
tapasco_res_t tapasco_async_wait_on_job(tapasco_async_t *a,
		tapasco_job_id_t const j_id);
tapasco_res_t tapasco_async_job_finished(tapasco_async_t *a,
		tapasco_job_id_t const j_id);
tapasco_res_t tapasco_async_enqueue_job(tapasco_async_t *a,
		tapasco_job_id_t const j_id);

#endif /* TAPASCO_ASYNC_H__ */
