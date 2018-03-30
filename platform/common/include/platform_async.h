#ifndef PLATFORM_ASYNC_H__
#define PLATFORM_ASYNC_H__

#include <platform_types.h>

typedef struct platform_async platform_async_t;

platform_res_t platform_async_init(platform_devctx_t const *pctx, platform_async_t **a);
void platform_async_deinit(platform_async_t *a);

platform_res_t platform_async_wait_for_slot(platform_async_t *a, platform_slot_id_t const slot);
platform_res_t platform_wait_for_slot(platform_devctx_t *ctx, platform_slot_id_t const slot);

#endif /* PLATFORM_ASYNC_H__ */
