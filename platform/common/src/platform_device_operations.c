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
		return PERR_TLKM_ERROR;
}

platform_res_t default_dealloc(platform_devctx_t *devctx,
		platform_mem_addr_t const addr,
		platform_alloc_flags_t const flags)
{
		return PERR_TLKM_ERROR;
}

platform_res_t default_read_mem(platform_devctx_t const *devctx,
		platform_mem_addr_t const addr,
		size_t const length,
		void *data,
		platform_mem_flags_t const flags)
{
		return PERR_TLKM_ERROR;
}

platform_res_t default_write_mem(platform_devctx_t const *devctx,
		platform_mem_addr_t const addr,
		size_t const length,
		void const *data,
		platform_mem_flags_t const flags)
{
		return PERR_TLKM_ERROR;
}

platform_res_t default_read_ctl(platform_devctx_t const *devctx,
		platform_ctl_addr_t const addr,
		size_t const length,
		void *data,
		platform_ctl_flags_t const flags)
{
	long ret = 0;
	DEVLOG(devctx->dev_id, LPLL_TLKM, "reading %zu bytes from 0x%08llx to 0x%08lx with flags 0x%08llx",
			length, (u64)addr, (ulong)data, (u64)flags);
	struct tlkm_copy_cmd cmd = {
		.length    = length,
		.user_addr = data,
		.dev_addr  = addr,
	};
	if ((ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_READ, &cmd))) {
		DEVERR(devctx->dev_id, "error reading from 0x%08llx: %s (%d)",
				(u64)addr, strerror(errno), errno);
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
	DEVLOG(devctx->dev_id, LPLL_TLKM, "writing %zu bytes from 0x%08lx to 0x%08llx with flags 0x%08llx",
			length, (ulong)data, (u64)addr, (u64)flags);
	struct tlkm_copy_cmd cmd = {
		.length    = length,
		.user_addr = (void *)data,
		.dev_addr  = addr,
	};
	if ((ret = ioctl(devctx->fd_ctrl, TLKM_DEV_IOCTL_WRITE, &cmd))) {
		DEVERR(devctx->dev_id, "error writing to 0x%08llx: %s (%d)",
				(u64)addr, strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	return PLATFORM_SUCCESS;
}
