#include <tapasco_async_dispatcher.h>
#include <tapasco_logging.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>

static
void *dispatcher_main(void *p)
{
	tapasco_async_t *a = (tapasco_async_t *)p;
	while (1) {
		tapasco_job_id_t j_id;
		while ((j_id = (tapasco_job_id_t)gq_dequeue(a->launch_q))) {
			LOG(LALL_ASYNC, "launching job %lu ...", j_id);
			gq_enqueue(a->finished_q, (void *)j_id);
		}
		usleep(10);
	}
	return NULL;
}

tapasco_res_t tapasco_async_dispatcher_init(tapasco_async_t *a)
{
	int const pr = pthread_create(&a->dispatcher,
			NULL, dispatcher_main, a);
	if (pr) {
		ERR("thread initialization failed with errno %d",
				pr);
		return TAPASCO_ERR_PTHREAD_ERROR;
	}
	return TAPASCO_SUCCESS;
}

void tapasco_async_dispatcher_deinit(tapasco_async_t *a)
{
	pthread_cancel(a->dispatcher);
	pthread_join(a->dispatcher, NULL);
	LOG(LALL_ASYNC, "dispatcher thread cancelled");
}
