#include <errno.h>
#include <gen_mem.h>
#include <platform_devctx.h>
#include <platform_device_operations.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <pthread.h>
#include <string.h>
#include <sys/mman.h>
#include <tlkm_device_ioctl_cmds.h>

typedef struct device_regspace {
  uintptr_t base;
  uintptr_t high;
  size_t size;
} device_regspace_t;

typedef struct device_regs {
  device_regspace_t status;
  device_regspace_t arch;
  device_regspace_t platform;
} device_regs_t;

#define DEFAULT_REGSPACE                                                       \
  {                                                                            \
    {                                                                          \
        .base = 0,                                                             \
        .high = 8192,                                                          \
        .size = 8192,                                                          \
    },                                                                         \
        {                                                                      \
            .base = 0x8000000,                                                 \
            .high = 0x8100000,                                                 \
            .size = 0x100000,                                                  \
        },                                                                     \
    {                                                                          \
      .base = 0x10000000, .high = 0x10100000, .size = 0x100000,                \
    }                                                                          \
  }

typedef struct default_platform {
  volatile void *arch_map;
  volatile void *plat_map;
  volatile void *status_map;
  platform_devctx_t *devctx;
  block_t *mem;
  pthread_mutex_t mem_mtx;
  device_regs_t regspace;
} default_platform_t;

volatile void *device_regspace_status_ptr(const platform_devctx_t *devctx) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  return pp->status_map;
}

size_t device_regspace_status_size(const platform_devctx_t *devctx) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  return pp->regspace.status.size;
}

uintptr_t device_regspace_status_base(const platform_devctx_t *devctx) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  return pp->regspace.status.base;
}

uintptr_t device_regspace_arch_base(const platform_devctx_t *devctx) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  return pp->regspace.arch.base;
}

volatile void *device_regspace_arch_ptr(const platform_devctx_t *devctx) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  return pp->arch_map;
}

uintptr_t device_regspace_platform_base(const platform_devctx_t *devctx) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  return pp->regspace.platform.base;
}

void calc_regspace(device_regspace_t *r) { r->high = r->base + (r->size - 1); }

platform_res_t default_alloc_driver(platform_devctx_t *devctx, size_t const len,
                                    platform_mem_addr_t *addr,
                                    platform_alloc_flags_t const flags) {
  DEVLOG(devctx->dev_id, LPLL_MM, "allocating %zu bytes with flags " PRIflags,
         len, (CSTflags)flags);
  struct tlkm_mm_cmd cmd = {
      .sz = len,
      .dev_addr = -1,
  };
  long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_ALLOC, &cmd);
  if (ret) {
    DEVERR(devctx->dev_id, "error allocating device memory: %s (%d)",
           strerror(errno), errno);
    return PERR_TLKM_ERROR;
  }
  *addr = cmd.dev_addr;
  return PLATFORM_SUCCESS;
}

platform_res_t default_dealloc_driver(platform_devctx_t *devctx,
                                      size_t const len,
                                      platform_mem_addr_t const addr,
                                      platform_alloc_flags_t const flags) {
  DEVLOG(devctx->dev_id, LPLL_MM,
         "freeing memory at " PRImem " with flags " PRIflags, addr,
         (CSTflags)flags);
  struct tlkm_mm_cmd cmd = {
      .sz = len,
      .dev_addr = addr,
  };
  long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_FREE, &cmd);
  if (ret) {
    DEVERR(devctx->dev_id, "error freeing device memory: %s (%d)",
           strerror(errno), errno);
    return PERR_TLKM_ERROR;
  }
  return PLATFORM_SUCCESS;
}

platform_res_t default_alloc_host(platform_devctx_t *devctx, size_t const len,
                                  platform_mem_addr_t *addr,
                                  platform_alloc_flags_t const flags) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  if (pp) {
    pthread_mutex_lock(&pp->mem_mtx);
    const addr_t a = gen_mem_malloc(&pp->mem, len);
    pthread_mutex_unlock(&pp->mem_mtx);
    if (a == INVALID_ADDRESS)
      return PERR_OUT_OF_MEMORY;
    else
      *addr = a;
  } else {
    return PERR_TLKM_ERROR;
  }

  return PLATFORM_SUCCESS;
}

platform_res_t default_dealloc_host(platform_devctx_t *devctx, size_t const len,
                                    platform_mem_addr_t const addr,
                                    platform_alloc_flags_t const flags) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  if (pp) {
    pthread_mutex_lock(&pp->mem_mtx);
    gen_mem_free(&pp->mem, addr, len);
    pthread_mutex_unlock(&pp->mem_mtx);
  } else {
    return PERR_TLKM_ERROR;
  }
  return PLATFORM_SUCCESS;
}

platform_res_t default_read_mem(platform_devctx_t const *devctx,
                                platform_mem_addr_t const addr,
                                size_t const length, void *data,
                                platform_mem_flags_t const flags) {
  DEVLOG(devctx->dev_id, LPLL_MM,
         "reading from device at " PRImem " with flags " PRIflags, addr,
         (CSTflags)flags);
  struct tlkm_copy_cmd cmd = {
      .length = length, .dev_addr = addr, .user_addr = data};
  long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_COPYFROM, &cmd);
  if (ret) {
    DEVERR(devctx->dev_id, "error reading device memory: %s (%d)",
           strerror(errno), errno);
    return PERR_TLKM_ERROR;
  }
  return PLATFORM_SUCCESS;
}

platform_res_t default_write_mem(platform_devctx_t const *devctx,
                                 platform_mem_addr_t const addr,
                                 size_t const length, void const *data,
                                 platform_mem_flags_t const flags) {
  DEVLOG(devctx->dev_id, LPLL_MM,
         "writing to device at " PRImem " with flags " PRIflags, addr,
         (CSTflags)flags);
  struct tlkm_copy_cmd cmd = {
      .length = length, .dev_addr = addr, .user_addr = (void *)data};
  long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_COPYTO, &cmd);
  if (ret) {
    DEVERR(devctx->dev_id, "error writing device memory: %s (%d)",
           strerror(errno), errno);
    return PERR_TLKM_ERROR;
  }
  return PLATFORM_SUCCESS;
}

platform_res_t default_read_ctl(platform_devctx_t const *devctx,
                                platform_ctl_addr_t const addr,
                                size_t const length, void *data,
                                platform_ctl_flags_t const flags) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  volatile void *r;
  DEVLOG(devctx->dev_id, LPLL_CTL, "addr = " PRIctl ", length = %zu", addr,
         length);

  if (IS_BETWEEN(addr, pp->regspace.arch.base, pp->regspace.arch.high)) {
    r = (void *)(((uintptr_t)pp->arch_map) + (addr - pp->regspace.arch.base));
  } else if (IS_BETWEEN(addr, pp->regspace.platform.base,
                        pp->regspace.platform.high)) {
    r = (void *)(((uintptr_t)pp->plat_map) +
                 (addr - pp->regspace.platform.base));
  } else if (IS_BETWEEN(addr, pp->regspace.status.base,
                        pp->regspace.status.high)) {
    r = (void *)(((uintptr_t)pp->status_map) +
                 (addr - pp->regspace.status.base));
  } else {
    DEVERR(devctx->dev_id, "invalid platform address: " PRIctl, addr);
    return PERR_CTL_INVALID_ADDRESS;
  }

  switch (length) {
  case 1:
    *((uint8_t *)data) = *((volatile uint8_t *)r);
    break;
  case 2:
    *((uint16_t *)data) = *((volatile uint16_t *)r);
    break;
  case 4:
    *((uint32_t *)data) = *((volatile uint32_t *)r);
    break;
  case 8:
    *((uint64_t *)data) = *((volatile uint64_t *)r);
    break;
  default:
    DEVERR(devctx->dev_id, "invalid size: %zd", length);
    return PERR_CTL_INVALID_SIZE;
  }

  return PLATFORM_SUCCESS;
}

platform_res_t default_write_ctl(platform_devctx_t const *devctx,
                                 platform_ctl_addr_t const addr,
                                 size_t const length, void const *data,
                                 platform_ctl_flags_t const flags) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  volatile void *r;
  DEVLOG(devctx->dev_id, LPLL_CTL, "addr = " PRIctl ", length = %zu", addr,
         length);

  if (IS_BETWEEN(addr, pp->regspace.arch.base, pp->regspace.arch.high))
    r = (volatile void *)(((uintptr_t)pp->arch_map) +
                          (addr - pp->regspace.arch.base));
  else if (IS_BETWEEN(addr, pp->regspace.platform.base,
                      pp->regspace.platform.high))
    r = (volatile void *)(((uintptr_t)pp->plat_map) +
                          (addr - pp->regspace.platform.base));
  else {
    DEVERR(devctx->dev_id, "invalid platform address: 0x%08lx",
           (unsigned long)addr);
    return PERR_CTL_INVALID_ADDRESS;
  }

  switch (length) {
  case 1:
    *((volatile uint8_t *)r) = *((uint8_t *)data);
    break;
  case 2:
    *((volatile uint16_t *)r) = *((uint16_t *)data);
    break;
  case 4:
    *((volatile uint32_t *)r) = *((uint32_t *)data);
    break;
  case 8:
    *((volatile uint64_t *)r) = *((uint64_t *)data);
    break;
  default:
    DEVERR(devctx->dev_id, "invalid size: %zd", length);
    return PERR_CTL_INVALID_SIZE;
  }

  return PLATFORM_SUCCESS;
}

static void default_unmap(default_platform_t *platform) {
  if (platform->arch_map != MAP_FAILED) {
    munmap((void *)platform->arch_map, platform->regspace.arch.size);
    platform->arch_map = MAP_FAILED;
  }
  if (platform->plat_map != MAP_FAILED) {
    munmap((void *)platform->plat_map, platform->regspace.platform.size);
    platform->plat_map = MAP_FAILED;
  }
  if (platform->status_map != MAP_FAILED) {
    munmap((void *)platform->status_map, platform->regspace.status.size);
    platform->status_map = MAP_FAILED;
  }
  DEVLOG(platform->devctx->dev_id, LPLL_DEVICE, "all I/O maps unmapped");
}

static platform_res_t default_map(default_platform_t *platform) {
  assert(platform->devctx);
  assert(platform->devctx->fd_ctrl);
  platform->arch_map = mmap(NULL, platform->regspace.arch.size,
                            PROT_READ | PROT_WRITE | PROT_EXEC, MAP_SHARED,
                            platform->devctx->fd_ctrl, 4096);
  if (platform->arch_map == MAP_FAILED) {
    DEVERR(platform->devctx->dev_id, "could not map architecture: %s (%d)",
           strerror(errno), errno);
    default_unmap(platform);
    return PERR_MMAP_DEV;
  }
  DEVLOG(platform->devctx->dev_id, LPLL_DEVICE,
         "successfully mapped architecture");

  platform->plat_map = mmap(NULL, platform->regspace.platform.size,
                            PROT_READ | PROT_WRITE | PROT_EXEC, MAP_SHARED,
                            platform->devctx->fd_ctrl, 8192);
  if (platform->plat_map == MAP_FAILED) {
    DEVERR(platform->devctx->dev_id, "could not map platform: %s (%d)",
           strerror(errno), errno);
    default_unmap(platform);
    return PERR_MMAP_DEV;
  }
  DEVLOG(platform->devctx->dev_id, LPLL_DEVICE, "successfully mapped platform");

  platform->status_map = mmap(NULL, platform->regspace.status.size,
                              PROT_READ | PROT_WRITE | PROT_EXEC, MAP_SHARED,
                              platform->devctx->fd_ctrl, 0);
  if (platform->status_map == MAP_FAILED) {
    DEVERR(platform->devctx->dev_id, "could not map status core: %s (%d)",
           strerror(errno), errno);
    default_unmap(platform);
    return PERR_MMAP_DEV;
  }
  DEVLOG(platform->devctx->dev_id, LPLL_DEVICE, "successfully mapped status");
  return PLATFORM_SUCCESS;
}

#define INIT_DEFAULT_PLATFORM                                                  \
  (default_platform_t) {                                                       \
    .arch_map = MAP_FAILED, .plat_map = MAP_FAILED, .status_map = MAP_FAILED,  \
    .devctx = NULL, .mem = NULL,                                               \
  }

platform_res_t request_device_size(platform_devctx_t const *devctx) {
  DEVLOG(devctx->dev_id, LPLL_MM,
         "Reading size of design components from driver.");
  struct tlkm_size_cmd cmd = {.arch = 0, .status = 0, .platform = 0};
  long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_SIZE, &cmd);
  if (ret) {
    DEVERR(devctx->dev_id, "error reading design size: %s (%d)",
           strerror(errno), errno);
    return PERR_TLKM_ERROR;
  }
  DEVLOG(devctx->dev_id, LPLL_MM, "Arch %dB, Platform %dB, Status %dB.",
         cmd.arch, cmd.platform, cmd.status);
  default_platform_t *pp = (default_platform_t *)devctx->private_data;

  pp->regspace = (device_regs_t)DEFAULT_REGSPACE;
  pp->regspace.arch.size = cmd.arch;
  pp->regspace.status.size = cmd.status;
  pp->regspace.platform.size = cmd.platform;
  calc_regspace(&pp->regspace.arch);
  calc_regspace(&pp->regspace.platform);
  calc_regspace(&pp->regspace.status);

  return PLATFORM_SUCCESS;
}

platform_res_t default_init(platform_devctx_t *devctx,
                            platform_mem_addr_t offboard_memory) {
  default_platform_t *pp =
      (default_platform_t *)malloc(sizeof(default_platform_t));
  if (!pp)
    return PERR_OUT_OF_MEMORY;
  pthread_mutex_init(&pp->mem_mtx, NULL);
  *pp = INIT_DEFAULT_PLATFORM;
  pp->devctx = devctx;
  if (offboard_memory) {
    pp->mem = gen_mem_create(0, offboard_memory);
    devctx->dops.alloc = default_alloc_host;
    devctx->dops.dealloc = default_dealloc_host;
  }
  devctx->private_data = pp;
  request_device_size(devctx);
  return default_map(pp);
}

platform_res_t default_deinit(platform_devctx_t const *devctx) {
  default_platform_t *pp = (default_platform_t *)devctx->private_data;
  pthread_mutex_destroy(&pp->mem_mtx);
  free(pp->mem);
  default_unmap(pp);
  pp->devctx = NULL;
  DEVLOG(devctx->dev_id, LPLL_DEVICE, "device released");
  return PLATFORM_SUCCESS;
}
