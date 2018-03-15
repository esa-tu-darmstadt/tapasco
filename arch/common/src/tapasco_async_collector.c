#include <tapasco_async_collector.h>
#include <tapasco_logging.h>
#include <pthread.h>
#include <unistd.h>

static
void *collector_main(void *p)
{
	tapasco_async_t *a = (tapasco_async_t *)p;
	while (1) {
		tapasco_job_id_t j_id = (tapasco_job_id_t)gq_dequeue(a->finished_q);
		if (j_id) {
			LOG(LALL_ASYNC, "job %lu finished", j_id);
			tapasco_async_job_finished(a, j_id);
		}
		usleep(10);
	}
	return NULL;
}

tapasco_res_t tapasco_async_collector_init(tapasco_async_t *a)
{
	int const pr = pthread_create(&a->collector,
			NULL, collector_main, a);
	if (pr) {
		ERR("thread initialization failed with errno %d",
				pr);
		return TAPASCO_ERR_PTHREAD_ERROR;
	}
	return TAPASCO_SUCCESS;
}

void tapasco_async_collector_deinit(tapasco_async_t *a)
{
	pthread_cancel(a->collector);
	pthread_join(a->collector, NULL);
	LOG(LALL_ASYNC, "collector thread cancelled");
}
