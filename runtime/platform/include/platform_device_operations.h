#ifndef PLATFORM_DEVICE_OPERATIONS_H__
#define PLATFORM_DEVICE_OPERATIONS_H__

#include "platform_types.h"
#include <stdlib.h>
typedef struct platform_devctx platform_devctx_t;

typedef struct platform_device_operations {
  platform_res_t (*alloc)(platform_devctx_t *devctx, size_t const len,
                          platform_mem_addr_t *addr,
                          platform_alloc_flags_t const flags);
  platform_res_t (*dealloc)(platform_devctx_t *devctx, size_t const len,
                            platform_mem_addr_t const addr,
                            platform_alloc_flags_t const flags);
  platform_res_t (*read_mem)(platform_devctx_t const *devctx,
                             platform_mem_addr_t const addr,
                             size_t const length, void *data,
                             platform_mem_flags_t const flags);
  platform_res_t (*write_mem)(platform_devctx_t const *devctx,
                              platform_mem_addr_t const addr,
                              size_t const length, void const *data,
                              platform_mem_flags_t const flags);
  platform_res_t (*read_ctl)(platform_devctx_t const *devctx,
                             platform_ctl_addr_t const addr,
                             size_t const length, void *data,
                             platform_ctl_flags_t const flags);
  platform_res_t (*write_ctl)(platform_devctx_t const *devctx,
                              platform_ctl_addr_t const addr,
                              size_t const length, void const *data,
                              platform_ctl_flags_t const flags);
  platform_res_t (*init)(platform_devctx_t *devctx,
                         platform_mem_addr_t offboard_memory);
  platform_res_t (*deinit)(platform_devctx_t const *devctx);
} platform_device_operations_t;

volatile void *device_regspace_status_ptr(const platform_devctx_t *devctx);
uintptr_t device_regspace_status_base(const platform_devctx_t *devctx);
size_t device_regspace_status_size(const platform_devctx_t *devctx);
volatile void *device_regspace_arch_ptr(const platform_devctx_t *devctx);
uintptr_t device_regspace_arch_base(const platform_devctx_t *devctx);
uintptr_t device_regspace_platform_base(const platform_devctx_t *devctx);

platform_res_t default_alloc_driver(platform_devctx_t *devctx, size_t const len,
                                    platform_mem_addr_t *addr,
                                    platform_alloc_flags_t const flags);

platform_res_t default_dealloc_driver(platform_devctx_t *devctx,
                                      size_t const len,
                                      platform_mem_addr_t const addr,
                                      platform_alloc_flags_t const flags);

platform_res_t default_alloc_host(platform_devctx_t *devctx, size_t const len,
                                  platform_mem_addr_t *addr,
                                  platform_alloc_flags_t const flags);

platform_res_t default_dealloc_host(platform_devctx_t *devctx, size_t const len,
                                    platform_mem_addr_t const addr,
                                    platform_alloc_flags_t const flags);

platform_res_t default_read_mem(platform_devctx_t const *devctx,
                                platform_mem_addr_t const addr,
                                size_t const length, void *data,
                                platform_mem_flags_t const flags);

platform_res_t default_write_mem(platform_devctx_t const *devctx,
                                 platform_mem_addr_t const addr,
                                 size_t const length, void const *data,
                                 platform_mem_flags_t const flags);

platform_res_t default_read_ctl(platform_devctx_t const *devctx,
                                platform_ctl_addr_t const addr,
                                size_t const length, void *data,
                                platform_ctl_flags_t const flags);

platform_res_t default_write_ctl(platform_devctx_t const *devctx,
                                 platform_ctl_addr_t const addr,
                                 size_t const length, void const *data,
                                 platform_ctl_flags_t const flags);

platform_res_t default_init(platform_devctx_t *devctx,
                            platform_mem_addr_t offboard_memory);
platform_res_t default_deinit(platform_devctx_t const *devctx);

static inline void default_dops(platform_device_operations_t *dops) {
  dops->alloc = default_alloc_driver;
  dops->dealloc = default_dealloc_driver;
  dops->read_mem = default_read_mem;
  dops->write_mem = default_write_mem;
  dops->read_ctl = default_read_ctl;
  dops->write_ctl = default_write_ctl;
  dops->init = default_init;
  dops->deinit = default_deinit;
}

#endif /* PLATFORM_DEVICE_OPERATIONS_H__ */
