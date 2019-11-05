#ifndef PLATFORM_CTX_H__
#define PLATFORM_CTX_H__

#include <platform.h>

platform_res_t _platform_init(const char *const version, platform_ctx_t **ctx);
void platform_deinit(platform_ctx_t *ctx);

platform_res_t platform_enum_devices(platform_ctx_t *ctx, size_t *num_devices,
                                     platform_device_info_t **devs);
platform_res_t platform_create_device(platform_ctx_t *ctx,
                                      platform_devctx_t **pdctx,
                                      platform_dev_id_t const dev_id,
                                      platform_access_t const mode);
void platform_destroy_device(platform_ctx_t *ctx, platform_devctx_t *pdctx);
void platform_destroy_device_by_id(platform_ctx_t *ctx,
                                   platform_dev_id_t const dev_id);

#endif /* PLATFORM_CTX_H__ */
