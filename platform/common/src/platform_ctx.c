#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <platform.h>
#include <platform_errors.h>
#include <platform_devfiles.h>
#include <platform_devctx.h>
#include <platform_logging.h>

struct platform_ctx {
	int				fd_tlkm;
	size_t				num_devs;
	platform_device_info_t		devs[PLATFORM_MAX_DEVS];
	char				version[TLKM_VERSION_SZ];
	platform_devctx_t		*devctx[PLATFORM_MAX_DEVS];
};

static
int get_tlkm_version(platform_ctx_t *ctx, char *v)
{
	struct tlkm_ioctl_version_cmd c = { .version = "", };
	if (ioctl(ctx->fd_tlkm, TLKM_IOCTL_VERSION, &c)) {
		ERR("getting version from device driver failed: %s (%d)", strerror(errno), errno);
		return errno;
	}
	strncpy(v, c.version, strlen(c.version) + 1);
	return 0;
}

static
int enum_devs(platform_ctx_t *ctx)
{
	int r = 0;
	assert(ctx);
	assert(ctx->fd_tlkm > 0);
	struct tlkm_ioctl_enum_devices_cmd c;
	memset(&c, 0, sizeof(c));
	if ((r = ioctl(ctx->fd_tlkm, TLKM_IOCTL_ENUM_DEVICES, &c))) {
		ERR("could not enumerate devices: %s (%d)", strerror(r), r);
		ctx->num_devs = 0;
		return PERR_TLKM_ERROR;
	}
	ctx->num_devs = c.num_devs;
	memcpy(ctx->devs, c.devs, sizeof(*(ctx->devs)) * c.num_devs);
	return 0;
}

static
platform_res_t get_dev(platform_ctx_t *ctx,
		platform_dev_id_t const dev_id,
		platform_device_info_t *info)
{
	if (dev_id >= ctx->num_devs) {
		ERR("unknown device #%02u", dev_id);
		return PERR_NO_SUCH_DEVICE;
	}
	memcpy(info, &ctx->devs[dev_id], sizeof(*info));
	return PLATFORM_SUCCESS;
}

static
platform_res_t init_platform(platform_ctx_t *ctx)
{
	platform_res_t r = PLATFORM_SUCCESS;
	ctx->fd_tlkm = open(TLKM_CONTROL_FN, O_RDWR);
	if (ctx->fd_tlkm == -1) {
		ERR("could not open " TLKM_CONTROL_FN ": %s (%d)", strerror(errno), errno);
		r = PERR_TLKM_ERROR;
		goto err_tlkm;
	}
	if (get_tlkm_version(ctx, ctx->version)) goto err_ioctl;
	LOG(LPLL_TLKM, "TLKM version: %s", ctx->version);

	if (enum_devs(ctx)) goto err_ioctl;
	LOG(LPLL_TLKM, "found %zu TaPaSCo devices:", ctx->num_devs);
	for (size_t i = 0; i < ctx->num_devs; ++i) {
		LOG(LPLL_TLKM, "  device #%02u: %s (%04x:%04x)", i, ctx->devs[i].name,
				ctx->devs[i].vendor_id, ctx->devs[i].product_id);
	}

	if (ctx->num_devs == 0) {
		ERR("found no TaPaSCo devices - is the device driver module tlkm loaded?");
		r = PERR_NO_DEVICES_FOUND;
		goto err_ioctl;
	}

	LOG(LPLL_TLKM, "platform context successfully initialized");
	return r;

err_ioctl:
	close(ctx->fd_tlkm);
err_tlkm:
	return r;
}

static
void deinit_platform(platform_ctx_t *ctx)
{
	close(ctx->fd_tlkm);
	LOG(LPLL_INIT, "platform deinited");
}

platform_res_t _platform_init(const char *const version, platform_ctx_t **ctx)
{
	platform_res_t r = PLATFORM_SUCCESS;
	platform_logging_init();
	LOG(LPLL_INIT, "Platform API Version: %s", platform_version());
	if (platform_check_version(version) != PLATFORM_SUCCESS) {
		ERR("Platform API version mismatch: found %s, expected %s", platform_version(), version);
		return PERR_VERSION_MISMATCH;
	}

	*ctx = (platform_ctx_t *)calloc(sizeof(**ctx), 1);
	if (! *ctx) {
		ERR("could not allocate platform_ctx");
		r = PERR_OUT_OF_MEMORY;
		goto err_ctx_alloc;
	}

	if ((r = init_platform(*ctx)) != PLATFORM_SUCCESS) {
		ERR("failed to initialize platform: %s (%d)", platform_strerror(r), r);
		goto err_init;
	}

	return r;

err_init:
	free(*ctx);
err_ctx_alloc:
	platform_logging_deinit();
	return r;
}

void platform_deinit(platform_ctx_t *ctx)
{
	deinit_platform(ctx);
	free(ctx);
	LOG(LPLL_INIT, "so long & thanks for all the fish, bye");
	platform_logging_deinit();
}

platform_res_t platform_enum_devices(platform_ctx_t *ctx,
		size_t *num_devs,
		platform_device_info_t **devs)
{
	*num_devs = ctx->num_devs;
	*devs = ctx->devs;
	return PLATFORM_SUCCESS;
}

platform_res_t platform_device_info(platform_ctx_t *ctx,
		platform_dev_id_t const dev_id,
		platform_device_info_t *info)
{
	return get_dev(ctx, dev_id, info);
}

platform_res_t platform_create_device(platform_ctx_t *ctx,
		platform_dev_id_t const dev_id,
		platform_access_t const mode,
		platform_devctx_t **pdctx)
{
	int r = 0;
	platform_res_t res = PLATFORM_SUCCESS;
	assert(ctx);
	assert(dev_id < PLATFORM_MAX_DEVS);
	assert(ctx->fd_tlkm > 0);
	struct tlkm_ioctl_device_cmd c = {
		.dev_id = dev_id,
		.access = mode,
	};
	if ((r = ioctl(ctx->fd_tlkm, TLKM_IOCTL_CREATE_DEVICE, &c))) {
		ERR("could not create device #%02u: %s (%d)", dev_id, strerror(errno), errno);
		return PERR_TLKM_ERROR;
	}
	LOG(LPLL_TLKM, "created device #%02u, initializing device context ...");
	if ((res = platform_devctx_init(ctx, dev_id, mode, &ctx->devctx[dev_id])) != PLATFORM_SUCCESS) {
		ERR("could not initialize device context for #%02u: %s (%d)",
				dev_id, platform_strerror(res), res);
		goto err_pdev;
	}
	if (pdctx) *pdctx = ctx->devctx[dev_id];
	LOG(LPLL_DEVICE, "successfully initialized device #%02u", dev_id);
	return PLATFORM_SUCCESS;

err_pdev:
	return res;
}

void platform_destroy_device_by_id(platform_ctx_t *ctx, platform_dev_id_t const dev_id)
{
	assert(dev_id < PLATFORM_MAX_DEVS);
	assert(ctx);
	assert(ctx->devctx[dev_id]);
	struct tlkm_ioctl_device_cmd c = {
		.dev_id = dev_id,
		.access = ctx->devctx[dev_id]->mode,
	};
	int r = 0;
	assert(ctx);
	assert(ctx->fd_tlkm > 0);
	assert(dev_id < PLATFORM_MAX_DEVS);
	platform_devctx_deinit(ctx->devctx[dev_id]);
	ctx->devctx[dev_id] = NULL;
	if ((r = ioctl(ctx->fd_tlkm, TLKM_IOCTL_DESTROY_DEVICE, &c))) {
		ERR("could not destroy device #%02u: %s (%d)", dev_id, strerror(errno), errno);
	} else {
		LOG(LPLL_DEVICE, "device #%02u destroyed", dev_id);
	}
}

void platform_destroy_device(platform_ctx_t *ctx, platform_devctx_t *pdctx)
{
	assert(pdctx);
	platform_destroy_device_by_id(ctx, pdctx->dev_id);
}
