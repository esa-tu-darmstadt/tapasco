#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include "tlkm_ioctl_cmds.h"

#define DEV_FN	"/dev/" TLKM_IOCTL_FN

static int init_device(int fd, size_t dev_id)
{
	struct tlkm_ioctl_device_cmd device_cmd = {
		.dev_id = dev_id,
	};
	int r = ioctl(fd, TLKM_IOCTL_CREATE_DEVICE, &device_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl create: %s (%d)\n", strerror(errno), errno);
		return r;
	}

	r = ioctl(fd, TLKM_IOCTL_DESTROY_DEVICE, &device_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl destroy: %s (%d)\n", strerror(errno), errno);
	}
	return r;
}

int main(int argc, char *argv[])
{
	int fd = open(DEV_FN, O_RDWR);
	if (! fd) {
		fprintf(stderr, "ERROR opening %s: %s (%d)\n", DEV_FN, strerror(errno), errno);
		return errno;
	}

	struct tlkm_ioctl_version_cmd version_cmd;
	int r = ioctl(fd, TLKM_IOCTL_VERSION, &version_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl version: %s (%d)\n", strerror(errno), errno);
		return r;
	} else {
		printf("TaPaSCo version: %s\n", version_cmd.version);
	}

	struct tlkm_ioctl_enum_devices_cmd enum_devices_cmd;
	r = ioctl(fd, TLKM_IOCTL_ENUM_DEVICES, &enum_devices_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl enum: %s (%d)\n", strerror(errno), errno);
		return r;
	} else {
		printf("Found %zu devices:\n", enum_devices_cmd.num_devs);
		for (size_t i = 0; i < enum_devices_cmd.num_devs; ++i) {
			printf("  device #%03zd: '%s' (%03x:%03x)\n",
					i, enum_devices_cmd.devs[i].name,
					enum_devices_cmd.devs[i].vendor_id,
					enum_devices_cmd.devs[i].product_id);
		}
		for (size_t i = 0; i < enum_devices_cmd.num_devs; ++i) {
			init_device(fd, i);
		}
	}

	close(fd);
}
