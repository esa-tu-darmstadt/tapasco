#include <stdio.h>
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
#include <platform_info.h>
#include <platform_devfiles.h>
#include <platform_addr_map.h>
#include <platform_signaling.h>
#include <platform_device_operations.h>
#include <platform_zynq.h>

platform_res_t platform_devctx_init(platform_ctx_t *ctx,
		platform_dev_id_t const dev_id,
		platform_access_t const mode,
		platform_devctx_t **pdctx)
{
	platform_res_t res = PLATFORM_SUCCESS;
	char *fn = control_file(dev_id);
	assert(ctx);
	assert(pdctx);
	assert(fn);
	platform_devctx_t *devctx = (platform_devctx_t *)calloc(sizeof(*devctx), 1);
	if (! devctx) {
		DEVERR(dev_id, "could not allocate memory for device context");
		free(fn);
		return PERR_OUT_OF_MEMORY;
	}

	DEVLOG(dev_id, LPLL_DEVICE, "preparing device ...");
	devctx->dev_id = dev_id;
	devctx->mode = mode;
	default_dops(&devctx->dops);

	if ((res = platform_device_info(ctx, dev_id, &devctx->dev_info)) != PLATFORM_SUCCESS) {
		DEVERR(dev_id, "could not get device information: %s (%d)", platform_strerror(res), res);
		free (devctx);
		free(fn);
		return res;
	}

	devctx->fd_ctrl = open(fn, O_RDWR);
	if (devctx->fd_ctrl == -1) {
		DEVERR(dev_id, "could not open %s: %s (%d)", fn, strerror(errno), errno);
		free(fn);
		res = PERR_OPEN_DEV;
		return res;
	}
	free(fn);

	if ((res = platform_info(devctx, &devctx->info)) != PLATFORM_SUCCESS) {
		DEVERR(dev_id, "could not get device info: %s (%d)", platform_strerror(res), res);
		goto err_info;
	}

	res = platform_addr_map_init(devctx, &devctx->info, &devctx->addrmap);
	if (res != PLATFORM_SUCCESS) {
		DEVERR(dev_id, "could not initialize platform address map: %s (%d)", platform_strerror(res), res);
		goto err_addr_map;
	}
	DEVLOG(dev_id, LPLL_INIT, "initialized device address map");

	res = platform_signaling_init(devctx, &devctx->signaling);
	if (res != PLATFORM_SUCCESS) {
		DEVERR(dev_id, "could not initialize signaling: %s (%d)", platform_strerror(res), res);
		goto err_signaling;
	}
	DEVLOG(dev_id, LPLL_INIT, "initialized device signaling");

	if ((res = zynq_init(devctx)) != PLATFORM_SUCCESS) {
		DEVERR(dev_id, "found no matching platform definition");
		goto err_platform;
	}

	if (pdctx) *pdctx = devctx;
	DEVLOG(dev_id, LPLL_INIT, "context initialization finished");
	return PLATFORM_SUCCESS;

	zynq_exit(devctx);
err_platform:
	platform_signaling_deinit(devctx->signaling);
err_signaling:
	platform_addr_map_deinit(devctx, devctx->addrmap);
err_addr_map:
err_info:
	close(devctx->fd_ctrl);
	return res;
}

static inline
void log_perfc(platform_devctx_t *devctx)
{
#ifndef NPERFC
	#define BUFSZ (1 << 12)
	char *fn = perfc_file(devctx->dev_id);
	char *buf = (char *)calloc(sizeof(*buf), BUFSZ);
	FILE *fp = fopen(fn, "r");
	size_t n = BUFSZ;
	if (fp) {
		while (getline(&buf, &n, fp) > 0) {
			buf[strcspn(buf, "\r\n")] = '\0';
			DEVLOG(devctx->dev_id, LPLL_DEVICE, "%s", buf);
		}
		fclose(fp);
	}
	free(buf);
	free(fn);
#endif
}

void platform_devctx_deinit(platform_devctx_t *devctx)
{
	if (devctx) {
		log_perfc(devctx);
		zynq_exit(devctx);
		platform_dev_id_t dev_id = devctx->dev_id;
		DEVLOG(dev_id, LPLL_INIT, "destroying platform signaling ...");
		platform_signaling_deinit(devctx->signaling);
		DEVLOG(dev_id, LPLL_INIT, "destroying platform address map ...");
		platform_addr_map_deinit(devctx, devctx->addrmap);
		close(devctx->fd_ctrl);
		devctx->fd_ctrl = -1;
		devctx->dev_id  = -1;
		free(devctx);
		DEVLOG(dev_id, LPLL_INIT, "context destroyed, have a nice 'un");
	}
}
