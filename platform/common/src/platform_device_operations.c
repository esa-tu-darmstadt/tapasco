#include <errno.h>
#include <string.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <tlkm_device_ioctl_cmds.h>
#include <platform_device_operations.h>
#include <platform_devctx.h>

platform_res_t default_alloc(platform_devctx_t *devctx,
		size_t const len,
		platform_mem_addr_t *addr,
		platform_alloc_flags_t const flags)
{
	DEVLOG(devctx->dev_id, LPLL_MM, "allocating %zu bytes with flags " PRIflags, len, (CSTflags) flags);
	struct tlkm_mm_cmd cmd = { .sz = len, .dev_addr = -1, };
	long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_ALLOC, &cmd);
	if (ret) {
		DEVERR(devctx->dev_id, "error allocating device memory: %s (%d)", strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	*addr = cmd.dev_addr;
	return PLATFORM_SUCCESS;
}

platform_res_t default_dealloc(platform_devctx_t *devctx,
		platform_mem_addr_t const addr,
		platform_alloc_flags_t const flags)
{
	DEVLOG(devctx->dev_id, LPLL_MM, "freeing memory at " PRImem " with flags " PRIflags, addr, (CSTflags) flags);
	struct tlkm_mm_cmd cmd = { .sz = 0, .dev_addr = addr, };
	long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_FREE, &cmd);
	if (ret) {
		DEVERR(devctx->dev_id, "error freeing device memory: %s (%d)", strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t default_read_mem(platform_devctx_t const *devctx,
		platform_mem_addr_t const addr,
		size_t const length,
		void *data,
		platform_mem_flags_t const flags)
{
	DEVLOG(devctx->dev_id, LPLL_MM, "reading from device at " PRImem " with flags " PRIflags, addr, (CSTflags) flags);
	struct tlkm_copy_cmd cmd = { .length = length, .dev_addr = addr, .user_addr = data };
	long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_COPYFROM, &cmd);
	if (ret) {
		DEVERR(devctx->dev_id, "error reading device memory: %s (%d)", strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t default_write_mem(platform_devctx_t const *devctx,
		platform_mem_addr_t const addr,
		size_t const length,
		void const *data,
		platform_mem_flags_t const flags)
{
	DEVLOG(devctx->dev_id, LPLL_MM, "writing to device at " PRImem " with flags " PRIflags, addr, (CSTflags)flags);
	struct tlkm_copy_cmd cmd = { .length = length, .dev_addr = addr, .user_addr = (void *)data };
	long ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_COPYTO, &cmd);
	if (ret) {
		DEVERR(devctx->dev_id, "error writing device memory: %s (%d)", strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t default_read_ctl(platform_devctx_t const *devctx,
		platform_ctl_addr_t const addr,
		size_t const length,
		void *data,
		platform_ctl_flags_t const flags)
{
	long ret = 0;
	DEVLOG(devctx->dev_id, LPLL_TLKM, "reading %zu bytes from " PRIctl " to %p with flags " PRIflags,
			length, addr, data, (CSTflags)flags);
	struct tlkm_copy_cmd cmd = {
		.length    = length,
		.user_addr = data,
		.dev_addr  = addr,
	};
	if ((ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_READ, &cmd))) {
		DEVERR(devctx->dev_id, "error reading from " PRIctl ": %s (%d)", addr, strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t default_write_ctl(platform_devctx_t const *devctx,
		platform_ctl_addr_t const addr,
		size_t const length,
		void const *data,
		platform_ctl_flags_t const flags)
{
	long ret = 0;
	DEVLOG(devctx->dev_id, LPLL_TLKM, "writing %zu bytes from %p to " PRIctl " with flags " PRIflags,
			length, data, addr, (CSTflags) flags);
	struct tlkm_copy_cmd cmd = {
		.length    = length,
		.user_addr = (void *)data,
		.dev_addr  = addr,
	};
	if ((ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_WRITE, &cmd))) {
		DEVERR(devctx->dev_id, "error writing to " PRIctl ": %s (%d)", addr, strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	return PLATFORM_SUCCESS;
}
