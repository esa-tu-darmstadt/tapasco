#include <linux/gfp.h>
#include <linux/slab.h>
#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_control.h"
#include "tlkm_class.h"
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
	status_base = dev->base_offset + dev->cls->status_base + TLKM_STATUS_REG_OFFSET;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "temporarily mapping 0x%08llx - 0x%08llx ...",
			status_base, status_base + TLKM_STATUS_SZ);
	component = (u64 *)ioremap_nocache(status_base, TLKM_STATUS_SZ);
	if (IS_ERR(component)) {
		DEVERR(dev->dev_id, "could not map status core registers: %ld", PTR_ERR(component));
	}
	memcpy_fromio(dma_base, component + PLATFORM_COMPONENT_DMA0, TLKM_DEVICE_MAX_DMA_ENGINES);
	iounmap(component);

	for (i = 0; i < TLKM_DEVICE_MAX_DMA_ENGINES; ++i) {
		struct dma_operations *o = &dev->dma[i].ops;
		DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "DMA%d base: 0x%08llx", i, dma_base[i]);
		if (! dma_base[i]) continue;
		dma_base[i] += dev->base_offset;
		ret = tlkm_dma_init(&dev->dma[i], dev->dev_id, (void *)dma_base[i], 0); // FIXME irq number?
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
		tlkm_dma_exit(&dev->dma[i]);
	return ret;
}

static
void dma_engines_exit(struct tlkm_device *dev)
{
	int i;
	for (i = 0; i < TLKM_DEVICE_MAX_DMA_ENGINES; ++i) {
		if (dev->dma[i].base) {
			tlkm_dma_exit(&dev->dma[i]);
		}
	}
}

int tlkm_device_init(struct tlkm_device *dev)
{
	int ret = 0;
	if ((ret = tlkm_control_init(dev->dev_id, &dev->ctrl))) {
		DEVERR(dev->dev_id, "could not setup control: %d", ret);
		goto err_control;
	}

	if ((ret = tlkm_perfc_miscdev_init(dev))) {
		DEVERR(dev->dev_id, "could not setup performance counter device file: %d", ret);
		goto err_nperfc;
	}

	if ((ret = dev->cls->create(dev))) {
		DEVERR(dev->dev_id, "failed to initialize private data struct: %d", ret);
		goto err_priv;
	}

	if ((ret = tlkm_status_init(&dev->status, dev, dev->base_offset + dev->cls->status_base))) {
		DEVERR(dev->dev_id, "coudl not initialize address map: %d", ret);
		goto err_status;
	}

	if ((ret = dma_engines_init(dev))) {
		DEVERR(dev->dev_id, "could not setup DMA engines for devices: %d", ret);
		goto err_dma;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "device setup complete");
	return ret;

	dma_engines_exit(dev);
err_dma:
	tlkm_status_exit(&dev->status, dev);
err_status:
	dev->cls->destroy(dev);
err_priv:
	tlkm_perfc_miscdev_exit(dev);
err_nperfc:
	tlkm_control_exit(dev->ctrl);
err_control:
	return ret;
}

static
int create_device_instance(struct tlkm_device *pdev, tlkm_access_t access)
{
	int ret = 0;

	if ((ret = tlkm_control_init(pdev->dev_id, &pdev->ctrl))) {
		ERR("could not setup control for device #%03u: %d", pdev->dev_id, ret);
		goto err_control;
	}

	if ((ret = tlkm_perfc_miscdev_init(pdev))) {
		DEVERR(pdev->dev_id, "could not setup performance counter device file: %d", ret);
		goto err_nperfc;
	}

	if ((ret = pdev->cls->create(pdev))) {
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
	pdev->cls->destroy(pdev);
err_priv:
	tlkm_perfc_miscdev_exit(pdev);
err_nperfc:
	tlkm_control_exit(pdev->ctrl);
err_control:
	return ret;
}

static
void destroy_device_instance(struct tlkm_device *pdev)
{
	pdev->cls->destroy(pdev);
	dma_engines_exit(pdev);
	tlkm_perfc_miscdev_exit(pdev);
	tlkm_control_exit(pdev->ctrl);
	kfree(pdev);
}

int tlkm_device_acquire(struct tlkm_device *pdev, tlkm_access_t access)
{
	int ret = 0;
	if (! pdev) {
		ERR("device does not exist");
		return -ENXIO;
	}

	mutex_lock(&pdev->mtx);
	DEVLOG(pdev->dev_id, TLKM_LF_DEVICE, "checking access mode ...");
	if (pdev->ref_cnt[TLKM_ACCESS_EXCLUSIVE]) {
		if (access != TLKM_ACCESS_MONITOR) {
			DEVERR(pdev->dev_id, "cannot share exclusive instance");
			ret = -EPERM;
		}
	}
	if (pdev->ref_cnt[TLKM_ACCESS_SHARED]) {
		if (access == TLKM_ACCESS_EXCLUSIVE) {
			DEVERR(pdev->dev_id, "cannot access shared instance exclusively");
			ret = -EPERM;
		}
	}
	if (! ret) {
		DEVLOG(pdev->dev_id, TLKM_LF_DEVICE, "ref_cnts: excl = %zu, shared = %zu, mon = %zu",
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
	if (! pdev) return;
	mutex_lock(&pdev->mtx);
	for (a = (tlkm_access_t)0; a < TLKM_ACCESS_TYPES; ++a) {
		total_refs += pdev->ref_cnt[a];
	}
	if (total_refs > 1) {
		DEVLOG(pdev->dev_id, TLKM_LF_DEVICE, "ref_cnt is %zu", total_refs);
		--pdev->ref_cnt[access];
	} else {
		DEVLOG(pdev->dev_id, TLKM_LF_DEVICE, "no longer referenced");
	}
	mutex_unlock(&pdev->mtx);
}
