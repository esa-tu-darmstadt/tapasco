/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo 
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include "tlkm_ioctl_cmds.h"
#include "tlkm_device_ioctl_cmds.h"

#define DEV_FN "/dev/" TLKM_IOCTL_FN

static int test_dev_ioctl(dev_id_t dev_id)
{
	int r = 0;
	struct tlkm_device_info info;
	char dfn[30] = "";
	snprintf(dfn, 30, "%s_%02u", DEV_FN, dev_id);

	int dfd = open(dfn, O_RDWR);
	if (dfd == -1) {
		return errno;
	}

	r = ioctl(dfd, TLKM_DEV_IOCTL_INFO, &info);
	if (!r) {
		printf("device name: %s\n", info.name);
	}

	getchar();

	close(dfd);
	return r;
}

static int init_device(int fd, size_t dev_id)
{
	struct tlkm_ioctl_device_cmd device_cmd = {
		.dev_id = dev_id,
	};
	int r = ioctl(fd, TLKM_IOCTL_CREATE_DEVICE, &device_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl create: %s (%d)\n",
			strerror(errno), errno);
		return r;
	}

	r = test_dev_ioctl(dev_id);
	if (r) {
		fprintf(stderr, "ERROR testing device ioctl: %s (%d)\n",
			strerror(errno), errno);
	}

	r = ioctl(fd, TLKM_IOCTL_DESTROY_DEVICE, &device_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl destroy: %s (%d)\n",
			strerror(errno), errno);
	}
	return r;
}

int main(int argc, char *argv[])
{
	int fd = open(DEV_FN, O_RDWR);
	if (!fd) {
		fprintf(stderr, "ERROR opening %s: %s (%d)\n", DEV_FN,
			strerror(errno), errno);
		return errno;
	}

	struct tlkm_ioctl_version_cmd version_cmd;
	int r = ioctl(fd, TLKM_IOCTL_VERSION, &version_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl version: %s (%d)\n",
			strerror(errno), errno);
		return r;
	} else {
		printf("TaPaSCo version: %s\n", version_cmd.version);
	}

	struct tlkm_ioctl_enum_devices_cmd enum_devices_cmd;
	r = ioctl(fd, TLKM_IOCTL_ENUM_DEVICES, &enum_devices_cmd);
	if (r) {
		fprintf(stderr, "ERROR ioctl enum: %s (%d)\n", strerror(errno),
			errno);
		return r;
	} else {
		printf("Found %zu devices:\n", enum_devices_cmd.num_devs);
		for (size_t i = 0; i < enum_devices_cmd.num_devs; ++i) {
			printf("  device #%03zd: '%s' (%04x:%04x)\n", i,
			       enum_devices_cmd.devs[i].name,
			       enum_devices_cmd.devs[i].vendor_id,
			       enum_devices_cmd.devs[i].product_id);
		}
		for (size_t i = 0; i < enum_devices_cmd.num_devs; ++i) {
			init_device(fd, i);
		}
	}

	close(fd);
}
