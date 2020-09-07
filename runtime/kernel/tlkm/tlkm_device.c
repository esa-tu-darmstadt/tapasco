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
#include <linux/gfp.h>
#include <linux/slab.h>
#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_control.h"
#include "tlkm_class.h"
#include "tlkm_perfc_miscdev.h"

#define TLKM_STATUS_SZ 0x1000
#define TLKM_STATUS_REG_OFFSET 0x1000

int tlkm_device_init(struct tlkm_device *dev, void *data)
{
	int ret = 0;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "setup performance counter file ...");
	if ((ret = tlkm_perfc_miscdev_init(dev))) {
		DEVERR(dev->dev_id,
		       "could not setup performance counter device file: %d",
		       ret);
		goto err_nperfc;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "setup device control  ...");
	if ((ret = tlkm_control_init(dev->dev_id, &dev->ctrl))) {
		DEVERR(dev->dev_id, "could not setup control: %d", ret);
		goto err_control;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "initializing device ...");
	if ((ret = dev->cls->create(dev, data))) {
		DEVERR(dev->dev_id,
		       "failed to initialize private data struct: %d", ret);
		goto err_priv;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "setup status I/O remap regions ...");
	if ((ret = tlkm_platform_status_init(dev, &dev->mmap))) {
		DEVERR(dev->dev_id, "could not map status I/O regions: %d",
		       ret);
		goto err_ioremap_status;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "reading status core ...");
	if ((ret = tlkm_status_init(&dev->status, dev, dev->mmap.status,
				    8192))) {
		DEVERR(dev->dev_id, "could not read status core: %d", ret);
		goto err_status;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "Arch @ 0x%llx (S: %lldB) Platform @ 0x%llx (S: %lldB)",
	       dev->status.arch_base.base, dev->status.arch_base.size,
	       dev->status.platform_base.base, dev->status.platform_base.size);

	dev->arch = (struct platform_regspace)INIT_REGSPACE(
		(dev->status.arch_base.base), (dev->status.arch_base.size));
	dev->plat = (struct platform_regspace)INIT_REGSPACE(
		(dev->status.platform_base.base),
		(dev->status.platform_base.size));

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "setup I/O remap regions ...");
	if ((ret = tlkm_platform_mmap_init(dev, &dev->mmap))) {
		DEVERR(dev->dev_id, "could not map I/O regions: %d", ret);
		goto err_ioremap;
	}

	if (dev->cls->init_subsystems) {
		DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
		       "setting up device-specific subsystems ...");
		if ((ret = dev->cls->init_subsystems(dev, data))) {
			DEVERR(dev->dev_id,
			       "could not setup device-specific subsystems: %d",
			       ret);
			goto err_sub;
		}
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "device setup complete");
	return ret;

err_sub:
	tlkm_platform_mmap_exit(dev, &dev->mmap);
err_ioremap:
	tlkm_status_exit(&dev->status, dev);
err_status:
	tlkm_platform_status_exit(dev, &dev->mmap);
err_ioremap_status:
	dev->cls->destroy(dev);
err_priv:
	tlkm_control_exit(dev->ctrl);
err_control:
	tlkm_perfc_miscdev_exit(dev);
err_nperfc:
	return ret;
}

void tlkm_device_exit(struct tlkm_device *dev)
{
	if (dev) {
		if (dev->cls->exit_subsystems)
			dev->cls->exit_subsystems(dev);
		tlkm_status_exit(&dev->status, dev);
		dev->cls->destroy(dev);
		tlkm_platform_status_exit(dev, &dev->mmap);
		tlkm_platform_mmap_exit(dev, &dev->mmap);
		tlkm_control_exit(dev->ctrl);
		tlkm_perfc_miscdev_exit(dev);
		DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "destroyed");
	}
}

int tlkm_device_acquire(struct tlkm_device *pdev, tlkm_access_t access)
{
	int ret = 0;
	if (!pdev) {
		ERR("device does not exist");
		return -ENXIO;
	}

	mutex_lock(&pdev->mtx);
	DEVLOG(pdev->dev_id, TLKM_LF_DEVICE, "checking access mode ...");
	if (pdev->ref_cnt[TLKM_ACCESS_EXCLUSIVE]) {
		if (access != TLKM_ACCESS_MONITOR) {
			DEVERR(pdev->dev_id, "cannot share exclusive instance");
			ret = -EBUSY;
		}
	}
	if (pdev->ref_cnt[TLKM_ACCESS_SHARED]) {
		if (access == TLKM_ACCESS_EXCLUSIVE) {
			DEVERR(pdev->dev_id,
			       "cannot access shared instance exclusively");
			ret = -EBUSY;
		}
	}
	if (!ret) {
		DEVLOG(pdev->dev_id, TLKM_LF_DEVICE,
		       "ref_cnts: excl = %zu, shared = %zu, mon = %zu",
		       pdev->ref_cnt[TLKM_ACCESS_EXCLUSIVE],
		       pdev->ref_cnt[TLKM_ACCESS_SHARED],
		       pdev->ref_cnt[TLKM_ACCESS_MONITOR]);
		++(pdev->ref_cnt[access]);
	}
	mutex_unlock(&pdev->mtx);
	return ret;
}

void tlkm_device_release(struct tlkm_device *pdev, tlkm_access_t access)
{
	tlkm_access_t a;
	size_t total_refs = 0;
	if (!pdev)
		return;
	mutex_lock(&pdev->mtx);
	for (a = (tlkm_access_t)0; a < TLKM_ACCESS_TYPES; ++a) {
		total_refs += pdev->ref_cnt[a];
	}
	if (total_refs > 0) {
		DEVLOG(pdev->dev_id, TLKM_LF_DEVICE, "ref_cnt is %zu",
		       total_refs);
		--pdev->ref_cnt[access];
	} else {
		DEVLOG(pdev->dev_id, TLKM_LF_DEVICE, "no longer referenced");
	}
	mutex_unlock(&pdev->mtx);
}
