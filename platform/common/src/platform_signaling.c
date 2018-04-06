#include <platform.h>
#include <platform_signaling.h>
#include <platform_devctx.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <pthread.h>
#include <semaphore.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <fcntl.h>

struct platform_signaling {
	int			fd_wait;
	platform_dev_id_t	dev_id;
	pthread_t 		collector;
	sem_t 			finished[PLATFORM_NUM_SLOTS];
};

static
void *platform_signaling_read_waitfile(void *p)
{
	platform_slot_id_t s = 0;
	assert(p);
	platform_signaling_t *a = (platform_signaling_t *)p;
	assert(a->fd_wait);
	do {
		if (read(a->fd_wait, &s, sizeof(s)) == sizeof(s)) {
			DEVLOG(a->dev_id, LPLL_ASYNC, "received finish notification from slot #%u", (unsigned)s);
			if (s < PLATFORM_NUM_SLOTS) sem_post(&a->finished[s]);
			else DEVERR(a->dev_id, "invalid slot id received: %u", (unsigned)s);
		}
	} while (1);
	return NULL;
}

platform_res_t platform_signaling_init(platform_devctx_t const *pctx, platform_signaling_t **a)
{
	*a = (platform_signaling_t *)malloc(sizeof(**a));
	if (! a) {
		DEVERR(pctx->dev_id, "could not allocate platform_signaling");
		return PERR_OUT_OF_MEMORY;
	}

	for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
		sem_init(&(*a)->finished[s], 0, 0);
	}

	(*a)->fd_wait = pctx->fd_ctrl;
	(*a)->dev_id  = pctx->dev_id;
	assert((*a)->fd_wait != -1);

	DEVLOG(pctx->dev_id, LPLL_ASYNC, "starting collector thread");
	int x = pthread_create(&(*a)->collector, NULL, platform_signaling_read_waitfile, *a);
	if (x != 0) {
		DEVERR(pctx->dev_id, "could not start collector thread: %s (%d)", strerror(errno), errno);
		free(*a);
		return PERR_PTHREAD_ERROR;
	}

	DEVLOG(pctx->dev_id, LPLL_ASYNC, "async initialized successfully");
	return PLATFORM_SUCCESS;
}

void platform_signaling_deinit(platform_signaling_t *a)
{
	platform_dev_id_t const dev_id = a->dev_id;
	pthread_cancel(a->collector);
	pthread_join(a->collector, NULL);

	close(a->fd_wait);

	for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
		sem_close(&a->finished[s]);
	}
	if (a) free(a);
	DEVLOG(dev_id, LPLL_ASYNC, "async deinitialized");
}

platform_res_t platform_signaling_wait_for_slot(platform_signaling_t *a, platform_slot_id_t const slot)
{
	DEVLOG(a->dev_id, LPLL_ASYNC, "waiting for slot #%lu", (unsigned long)slot);
	sem_wait(&a->finished[slot]);
	DEVLOG(a->dev_id, LPLL_ASYNC, "slot #%lu has finished", (unsigned long)slot);
	return PLATFORM_SUCCESS;
}

platform_res_t platform_wait_for_slot(platform_devctx_t *ctx, platform_slot_id_t const s)
{
	return platform_signaling_wait_for_slot(ctx->signaling, s);
}
