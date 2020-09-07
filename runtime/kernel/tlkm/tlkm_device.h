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
#ifndef TLKM_DEVICE_H__
#define TLKM_DEVICE_H__

#include <linux/pci.h>
#include <linux/list.h>
#include <linux/mutex.h>
#include <linux/miscdevice.h>
#include "tlkm_logging.h"
#include "tlkm_types.h"
#include "tlkm_perfc.h"
#include "tlkm_access.h"
#include "tlkm_status.h"
#include "tlkm_class.h"

#define TLKM_DEVICE_NAME_LEN 30
#define TLKM_DEVICE_MAX_DMA_ENGINES 4

struct platform_mmap;

struct tlkm_device {
	struct list_head device; /* this device in tlkm_bus */
	struct mutex mtx;
	struct tlkm_class *cls; /* class of the device */
	dev_id_t dev_id; /* id of the device in tlkm_bus */
	char name[TLKM_DEVICE_NAME_LEN];
	size_t ref_cnt[TLKM_ACCESS_TYPES];
	int vendor_id;
	int product_id;
	dev_addr_t base_offset; /* physical base offset of bitstream */
	struct platform_mmap mmap; /* I/O remaps of register spaces */
	tlkm_status status; /* bitstream information */
	struct platform_regspace arch;
	struct platform_regspace plat;
	struct tlkm_control *ctrl; /* main device file */
	tlkm_component_t components[TLKM_COMPONENT_MAX];
#ifndef NPERFC
	struct miscdevice perfc_dev; /* performance counter device */
#endif
	void *private_data; /* implementation-specific data */
};

int tlkm_device_init(struct tlkm_device *pdev, void *data);
void tlkm_device_exit(struct tlkm_device *pdev);
int tlkm_device_acquire(struct tlkm_device *pdev, tlkm_access_t access);
void tlkm_device_release(struct tlkm_device *pdev, tlkm_access_t access);

static inline int tlkm_device_request_platform_irq(struct tlkm_device *dev,
						   int irq_no, irq_handler_t h,
						   void *data)
{
	BUG_ON(!dev);
	BUG_ON(!dev->cls);
	if (!dev->cls->pirq) {
		DEVERR(dev->dev_id,
		       "platform interrupt request callback not defined");
		return -ENXIO;
	}
	return dev->cls->pirq(dev, irq_no, h, data);
}

static inline void tlkm_device_release_platform_irq(struct tlkm_device *dev,
						    int irq_no)
{
	BUG_ON(!dev);
	BUG_ON(!dev->cls);
	if (!dev->cls->rirq) {
		DEVERR(dev->dev_id,
		       "platform interrupt release callback not defined");
	} else {
		dev->cls->rirq(dev, irq_no);
	}
}

#endif /* TLKM_DEVICE_H__ */
