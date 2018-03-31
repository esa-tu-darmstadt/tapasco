#ifndef PLATFORM_ASYNC_H__
#define PLATFORM_ASYNC_H__

#include <platform_types.h>

typedef struct platform_signaling platform_signaling_t;

platform_res_t platform_signaling_init(platform_devctx_t const *pctx, platform_signaling_t **a);
void platform_signaling_deinit(platform_signaling_t *a);

platform_res_t platform_signaling_wait_for_slot(platform_signaling_t *a, platform_slot_id_t const slot);
platform_res_t platform_wait_for_slot(platform_devctx_t *ctx, platform_slot_id_t const slot);

#endif /* PLATFORM_ASYNC_H__ */
