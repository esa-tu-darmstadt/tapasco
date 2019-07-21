#ifndef PLATFORM_ASYNC_H__
#define PLATFORM_ASYNC_H__

#include <platform_types.h>

typedef struct platform_signaling platform_signaling_t;
typedef void (*platform_signal_received_f)(size_t num,
                                           platform_slot_id_t *slots);

platform_res_t platform_signaling_init(platform_devctx_t const *pctx,
                                       platform_signaling_t **a);
void platform_signaling_deinit(platform_signaling_t *a);

platform_res_t platform_signaling_wait_for_slot(platform_signaling_t *a,
                                                platform_slot_id_t const slot);
platform_res_t platform_wait_for_slot(platform_devctx_t *ctx,
                                      platform_slot_id_t const slot);

void platform_signaling_signal_received(platform_signaling_t *s,
                                        platform_signal_received_f callback);

#endif /* PLATFORM_ASYNC_H__ */
