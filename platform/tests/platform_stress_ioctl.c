#include <stdio.h>
#include <platform.h>

#define NUM_RUNS				100

static
void stress(platform_ctx_t *ctx, platform_dev_id_t dev_id)
{
	platform_res_t res = PLATFORM_SUCCESS;
	for (size_t i = NUM_RUNS; i > 0 && res == PLATFORM_SUCCESS; --i) {
		res = platform_create_device(ctx, dev_id, PLATFORM_EXCLUSIVE_ACCESS, NULL);
		if (res == PLATFORM_SUCCESS)
			platform_destroy_device(ctx, dev_id);
	}
}

int main(int argc, char *argv[])
{
	platform_ctx_t *ctx;
	size_t num_devs = 0;
	platform_device_info_t *devs;
	platform_res_t res = platform_init(&ctx);
	if (res != PLATFORM_SUCCESS) {
		fprintf(stderr, "could not initialize platform: %s (%d)", platform_strerror(res), res);
		exit(EXIT_FAILURE);
	}

	platform_enum_devices(ctx, &num_devs, &devs);
	for (size_t i = 0; i < num_devs; ++i) {
		printf("Stressing device #%03u ...\n", i);
		stress(ctx, i);
	}
	platform_deinit(ctx);
}
