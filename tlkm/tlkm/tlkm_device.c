#include <linux/gfp.h>
#include <linux/slab.h>
#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_control.h"
#include "tlkm_perfc_miscdev.h"
#include "platform_components.h"

#define TLKM_STATUS_SZ					0x1000
#define	TLKM_STATUS_REG_OFFSET				0x1000

static
int dma_engines_init(struct tlkm_device *dev)
{
	int i, ret = 0, irqn = 0;
	u64 *component;
	u64 dma_base[TLKM_DEVICE_MAX_DMA_ENGINES] = { 0ULL, };
	u64 status_base;
	BUG_ON(! dev);
	status_base = dev->base_offset + dev->status_base + TLKM_STATUS_REG_OFFSET;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "temporarily mapping 0x%08llx - 0x%08llx ...",
			status_base, status_base + TLKM_STATUS_SZ);
	component = (u64 *)ioremap_nocache(status_base, TLKM_STATUS_SZ);
	if (IS_ERR(component)) {
		DEVERR(dev->dev_id, "could not map status core registers: %ld", PTR_ERR(component));
	}
	memcpy_fromio(dma_base, component + PLATFORM_COMPONENT_DMA0, TLKM_DEVICE_MAX_DMA_ENGINES);
	iounmap(component);

	for (i = 0; i < TLKM_DEVICE_MAX_DMA_ENGINES; ++i) {
		struct dma_operations *o = &dev->inst->dma[i].ops;
		DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "DMA%d base: 0x%08llx", i, dma_base[i]);
		if (! dma_base[i]) continue;
		dma_base[i] += dev->base_offset;
		BUG_ON(! dev->inst);
		ret = tlkm_dma_init(&dev->inst->dma[i], dev->dev_id, (void *)dma_base[i], 0); // FIXME irq number?
		if (ret) {
			DEVERR(dev->dev_id, "failed to initialize DMA%d: %d", i, ret);
			goto err_dma_engine;
		}

		BUG_ON(! o->intr_read);
		if (o->intr_read && (ret = tlkm_device_request_platform_irq(dev, irqn++, o->intr_read))) {
			DEVERR(dev->dev_id, "could not register interrupt #%d: %d", irqn, ret);
			goto err_dma_engine;
		}
		if (o->intr_write && o->intr_write != o->intr_read && (ret = tlkm_device_request_platform_irq(dev, irqn++, o->intr_write))) {
			DEVERR(dev->dev_id, "could not register interrupt #%d: %d", irqn, ret);
			goto err_dma_engine;
		}
	}
	return ret;

err_dma_engine:
	for (; i >= 0; --i)
		tlkm_dma_exit(&dev->inst->dma[i]);
	return ret;
}

static
void dma_engines_exit(struct tlkm_device *dev)
{
	int i;
	for (i = 0; i < TLKM_DEVICE_MAX_DMA_ENGINES; ++i) {
		if (dev->inst->dma[i].base) {
			tlkm_dma_exit(&dev->inst->dma[i]);
		}
	}
}

static
int create_device_instance(struct tlkm_device *pdev, tlkm_access_t access)
{
	int ret = 0;
	pdev->inst = kmalloc(sizeof(*(pdev->inst)), GFP_KERNEL);
	if (! pdev->inst) {
		ERR("could not allocate kernel memory for device instance");
		return -ENOMEM;
	}
	memset(pdev->inst, 0, sizeof(*(pdev->inst)));
	pdev->inst->dev_id 		= pdev->dev_id;
	pdev->inst->ref_cnt[access] 	= 1;
	pdev->inst->private_data 	= NULL;

	if ((ret = tlkm_control_init(pdev->dev_id, &pdev->inst->ctrl))) {
		ERR("could not setup control for device #%03u: %d", pdev->dev_id, ret);
		goto err_control;
	}

	if ((ret = tlkm_perfc_miscdev_init(pdev->inst))) {
		DEVERR(pdev->dev_id, "could not setup performance counter device file: %d", ret);
		goto err_nperfc;
	}

	if ((ret = pdev->init(pdev->inst))) {
		DEVERR(pdev->dev_id, "failed to initialize private data struct: %d", ret);
		goto err_priv;
	}

	if ((ret = dma_engines_init(pdev))) {
		DEVERR(pdev->dev_id, "could not setup DMA engines for devices: %d", ret);
		goto err_dma;
	}

	return ret;

	dma_engines_exit(pdev);
err_dma:
	pdev->exit(pdev->inst);
err_priv:
	tlkm_perfc_miscdev_exit(pdev->inst);
err_nperfc:
	tlkm_control_exit(pdev->inst->ctrl);
err_control:
	kfree(pdev->inst);
	pdev->inst = NULL;
	return ret;
}

static
void destroy_device_instance(struct tlkm_device *pdev)
{
	if (pdev->inst) {
		pdev->exit(pdev->inst);
		dma_engines_exit(pdev);
		tlkm_perfc_miscdev_exit(pdev->inst);
		tlkm_control_exit(pdev->inst->ctrl);
		kfree(pdev->inst);
		pdev->inst = NULL;
	}
}

int tlkm_device_create(struct tlkm_device *pdev, tlkm_access_t access)
{
	int ret = 0;
	if (! pdev) {
		ERR("device does not exist");
		return -ENXIO;
	}

	mutex_lock(&pdev->mtx);
	if (pdev->inst) {
		LOG(TLKM_LF_DEVICE, "instance for device #%03u already exists, "
				"checking permissions ...", pdev->dev_id);
		if (pdev->inst->ref_cnt[TLKM_ACCESS_EXCLUSIVE]) {
			if (access != TLKM_ACCESS_MONITOR) {
				ERR("cannot share exclusive instance for device #%03u",
						pdev->dev_id);
				ret = -EPERM;
			}
		}
		if (pdev->inst->ref_cnt[TLKM_ACCESS_SHARED]) {
			if (access == TLKM_ACCESS_EXCLUSIVE) {
				ERR("shared instance for device #%03u exists, "
						"cannot access exclusively",
						pdev->dev_id);
				ret = -EPERM;
			}
		}
		if (! ret) {
			LOG(TLKM_LF_DEVICE, "instance for device #%03u exists",
					pdev->dev_id);
			LOG(TLKM_LF_DEVICE, "ref_cnts: excl = %zu, shared = %zu, mon = %zu",
					pdev->inst->ref_cnt[TLKM_ACCESS_EXCLUSIVE],
					pdev->inst->ref_cnt[TLKM_ACCESS_SHARED],
					pdev->inst->ref_cnt[TLKM_ACCESS_MONITOR]);
			++(pdev->inst->ref_cnt[access]);
		}
	} else {
		LOG(TLKM_LF_DEVICE, "instance for device #%03u does not exist, "
				"creating ...", pdev->dev_id);
		ret = create_device_instance(pdev, access);
	}
	mutex_unlock(&pdev->mtx);
	return ret;
}

void tlkm_device_destroy(struct tlkm_device *pdev, tlkm_access_t access)
{
	tlkm_access_t a;
	if (! pdev) return;
	mutex_lock(&pdev->mtx);
	if (pdev->inst) {
		size_t total_refs = 0;
		for (a = (tlkm_access_t)0; a < TLKM_ACCESS_TYPES; ++a) {
			total_refs += pdev->inst->ref_cnt[a];
		}
		if (total_refs > 1) {
			LOG(TLKM_LF_DEVICE, "ref_cnt of instance for device #%03u is %zu",
					pdev->dev_id, total_refs);
			--pdev->inst->ref_cnt[access];
		} else {
			LOG(TLKM_LF_DEVICE, "instance for device #%03u is no longer referenced",
					pdev->dev_id);
			destroy_device_instance(pdev);
		}
	} else {
		WRN("device #%03u has not yet been created or is already destroyed", pdev->dev_id);
	}
	mutex_unlock(&pdev->mtx);
}

void tlkm_device_remove_all(struct tlkm_device *pdev)
{
	if (! pdev) return;
	mutex_lock(&pdev->mtx);
	if (pdev->inst) {
		destroy_device_instance(pdev);
	}
	mutex_unlock(&pdev->mtx);
}
