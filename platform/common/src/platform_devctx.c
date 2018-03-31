#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <platform.h>
#include <platform_devctx.h>
#include <platform_types.h>
#include <platform_logging.h>
#include <platform_devfiles.h>
#include <platform_addr_map.h>
#include <platform_async.h>

struct platform_devctx {
	platform_dev_id_t			dev_id;
	int					fd_ctrl;
	platform_access_t			mode;
	platform_info_t 			info;
	platform_addr_map_t 			*addrmap;
	platform_async_t 			*async;
};

platform_dev_id_t platform_devctx_dev_id(platform_devctx_t const *ctx)
{
	return ctx->dev_id;
}

int platform_devctx_control(platform_devctx_t const *ctx)
{
	return ctx->fd_ctrl;
}

platform_access_t platform_devctx_access(platform_devctx_t const *ctx)
{
	return ctx->mode;
}

platform_addr_map_t *platform_devctx_addr_map(platform_devctx_t const *ctx)
{
	return ctx->addrmap;
}

platform_async_t *platform_devctx_async(platform_devctx_t const *ctx)
{
	return ctx->async;
}

platform_res_t platform_devctx_init(platform_devctx_t **ctx, platform_dev_id_t const dev_id,
		platform_access_t const mode)
{
	platform_res_t res = PLATFORM_SUCCESS;
	char *fn = control_file(dev_id);
	assert(ctx);
	assert(fn);
	platform_devctx_t *devctx = (platform_devctx_t *)calloc(sizeof(*devctx), 1);
	if (! devctx) {
		ERR("device #%03u: could not allocate memory for device context", dev_id);
		return PERR_OUT_OF_MEMORY;
	}

	LOG(LPLL_DEVICE, "preparing device #%03u ...", dev_id);
	devctx->dev_id = dev_id;
	devctx->mode = mode;
	devctx->fd_ctrl = open(control_file(dev_id), O_RDWR);
	if (devctx->fd_ctrl == -1) {
		ERR("could not open %s: %s (%d)", fn, strerror(errno), errno);
		res = PERR_OPEN_DEV;
	}
	free(fn);

	if ((res = platform_info(devctx, &devctx->info)) != PLATFORM_SUCCESS) {
		ERR("device #%03u: could not get device info: %s (%d)",
				dev_id, platform_strerror(res), res);
		goto err_info;
	}

	res = platform_addr_map_init(devctx, &devctx->info, &devctx->addrmap);
	if (res != PLATFORM_SUCCESS) {
		ERR("device #%03u: could not initialize platform address map: %s (%d)",
				dev_id, platform_strerror(res), res);
		goto err_addr_map;
	}
	LOG(LPLL_INIT, "device #%03u: initialized device address map", dev_id);

	res = platform_async_init(devctx, &devctx->async);
	if (res != PLATFORM_SUCCESS) {
		ERR("device #%03u: could not initialize async: %s (%d)",
				dev_id, platform_strerror(res), res);
		goto err_async;
	}
	LOG(LPLL_INIT, "device #%03u: initialized device async", dev_id);

	*ctx = devctx;
	LOG(LPLL_INIT, "device #%03u: context initialization finished", dev_id);
	return PLATFORM_SUCCESS;

err_async:
	platform_addr_map_deinit(devctx, devctx->addrmap);
err_addr_map:
err_info:
	close(devctx->fd_ctrl);
	return res;
}

void platform_devctx_deinit(platform_devctx_t *devctx)
{
	if (devctx) {
		platform_dev_id_t dev_id = devctx->dev_id;
		LOG(LPLL_INIT, "device #%03u: destroying platform async ...", dev_id);
		platform_async_deinit(devctx->async);
		LOG(LPLL_INIT, "device #%03u: destroying platform address map ...", dev_id);
		platform_addr_map_deinit(devctx, devctx->addrmap);
		close(devctx->fd_ctrl);
		devctx->fd_ctrl = -1;
		devctx->dev_id  = -1;
		free(devctx);
		LOG(LPLL_INIT, "device #%03u: context destroyed, have a nice 'un", dev_id);
	}
}
