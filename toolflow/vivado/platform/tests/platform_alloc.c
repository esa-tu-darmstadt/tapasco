#include <stdio.h>
#include <platform.h>

int main(int argc, char *argv[])
{
	platform_res_t res;
	platform_ctx_t *ctx;
	platform_devctx_t *devctx;
	platform_mem_addr_t addr;
	size_t sz = argc > 1 ? strtoul(argv[1], NULL, 0) : 1024;

	platform_init(&ctx);
	platform_devctx_init(ctx, 0, PLATFORM_SHARED_ACCESS, &devctx);

	if ((res = platform_alloc(devctx, sz, &addr, 0)) != PLATFORM_SUCCESS) {
		fprintf(stderr, "platform error during allocation: %s", platform_strerror(res));
	} else {
		if ((res = platform_dealloc(devctx, addr, 0)) != PLATFORM_SUCCESS) {
			fprintf(stderr, "platform error during free: %s", platform_strerror(res));
		}
	}
	return res != PLATFORM_SUCCESS;
}
