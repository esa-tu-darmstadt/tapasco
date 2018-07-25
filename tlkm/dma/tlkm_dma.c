#include <linux/gfp.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/io.h>
#include "tlkm_dma.h"
#include "tlkm_logging.h"
#include "tlkm_perfc.h"
#include "blue_dma.h"
#include "dual_dma.h"
#include "pcie/pcie_device.h"

#define REG_ID 						0x18
#define DMA_SZ						0x10000

static const struct dma_operations tlkm_dma_ops[] = {
	[DMA_USED_DUAL] = {
		.intr_read		 = dual_dma_intr_handler_dma, // Dual DMA can not read and write in parallel
		.intr_write		 = dual_dma_intr_handler_dma,
		.copy_from		 = dual_dma_copy_from,
		.copy_to	     = dual_dma_copy_to,
		.allocate_buffer = pcie_device_dma_allocate_buffer,
		.free_buffer 	 = pcie_device_dma_free_buffer,
		.buffer_cpu      = pcie_device_dma_sync_buffer_cpu,
		.buffer_dev      = pcie_device_dma_sync_buffer_dev,
	},
	[DMA_USED_BLUE] = {
		.intr_read	= blue_dma_intr_handler_read,
		.intr_write	= blue_dma_intr_handler_write,
		.copy_from	= blue_dma_copy_from,
		.copy_to	= blue_dma_copy_to,
		.allocate_buffer = pcie_device_dma_allocate_buffer,
		.free_buffer 	 = pcie_device_dma_free_buffer,
		.buffer_cpu      = pcie_device_dma_sync_buffer_cpu,
		.buffer_dev      = pcie_device_dma_sync_buffer_dev,
	},
};

int tlkm_dma_init(struct tlkm_device *dev, struct dma_engine *dma, u64 dbase)
{
	dev_id_t dev_id = dev->dev_id;
	uint64_t id;
	int ret = 0;
	void *base = (void *)((uintptr_t)dbase);
	BUG_ON(! dma);
	DEVLOG(dev_id, TLKM_LF_DMA, "initializing DMA engine @ 0x%px ...", base);

	DEVLOG(dev_id, TLKM_LF_DMA, "I/O remapping 0x%px - 0x%px...", base, base + DMA_SZ - 1);
	dma->regs = ioremap_nocache((resource_size_t)base, DMA_SZ);
	if (dma->regs == 0 || IS_ERR(dma->regs)) {
		DEVERR(dev_id, "failed to map 0x%px - 0x%px: %ld", base, base + DMA_SZ - 1, PTR_ERR(dma->regs));
		ret = EIO;
        goto err_dma_ioremap;
	}

	DEVLOG(dev_id, TLKM_LF_DMA, "detecting DMA engine type ...");
	id = *(u64 *)(dma->regs + REG_ID);
	if ((id & 0xFFFFFFFF) == BLUE_DMA_ID) {
		dma->dma_used = DMA_USED_BLUE;
		DEVLOG(dev_id, TLKM_LF_DMA, "detected BlueDMA");
		DEVLOG(dev_id, TLKM_LF_DMA, "PCIe beats per burst: %u", (uint8_t)(id >> 32));
		DEVLOG(dev_id, TLKM_LF_DMA, "FPGA beats per burst: %u", (uint8_t)(id >> 40));
		DEVLOG(dev_id, TLKM_LF_DMA, "smallest alignment: %u", (uint8_t)(id >> 48));
		dma->alignment = (uint8_t)(id >> 48);
	} else {
		dma->dma_used = DMA_USED_DUAL;
		dma->alignment = 64;
		DEVLOG(dev_id, TLKM_LF_DMA, "detected DualDMA");
	}
	dma->ops = tlkm_dma_ops[dma->dma_used];

	DEVLOG(dev_id, TLKM_LF_DMA, "allocating DMA buffers of %zd bytes ...", TLKM_DMA_BUF_SZ);

	ret = dma->ops.allocate_buffer(dev->dev_id, dev, &dma->dma_buf_read, &dma->dma_buf_read_dev, FROM_DEV, TLKM_DMA_BUF_SZ);
	if (ret) {
		ret = PTR_ERR(dma->dma_buf_read);
        DEVERR(dev_id, "failed to allocate %zd bytes for read direction", TLKM_DMA_BUF_SZ);
		goto err_dma_bufs_read;
	}

	ret = dma->ops.allocate_buffer(dev->dev_id, dev, &dma->dma_buf_write, &dma->dma_buf_write_dev, TO_DEV, TLKM_DMA_BUF_SZ);
	if (ret) {
		ret = PTR_ERR(dma->dma_buf_write);
        DEVERR(dev_id, "failed to allocate %zd bytes for write direction", TLKM_DMA_BUF_SZ);
		goto err_dma_bufs_write;
	}

	init_waitqueue_head(&dma->rq);
	init_waitqueue_head(&dma->wq);
	mutex_init(&dma->regs_mutex);
	mutex_init(&dma->rq_mutex);
	mutex_init(&dma->wq_mutex);
	dma->dev_id = dev_id;
	dma->base = base;
	dma->dev = dev;
	atomic64_set(&dma->rq_enqueued, 0);
	atomic64_set(&dma->rq_processed, 0);
	atomic64_set(&dma->wq_enqueued, 0);
	atomic64_set(&dma->wq_processed, 0);
	DEVLOG(dev_id, TLKM_LF_DMA, "DMA engine initialized");
	return 0;

err_dma_bufs_write:
	dma->ops.free_buffer(dev->dev_id, dev, &dma->dma_buf_read, &dma->dma_buf_read_dev, FROM_DEV, TLKM_DMA_BUF_SZ);
err_dma_bufs_read:
    iounmap(dma->regs);
err_dma_ioremap:
	return ret;
}

void tlkm_dma_exit(struct dma_engine *dma)
{
	struct tlkm_device *dev = dma->dev;
	dma->ops.free_buffer(dev->dev_id, dev, &dma->dma_buf_write, &dma->dma_buf_write_dev, TO_DEV, TLKM_DMA_BUF_SZ);
	dma->ops.free_buffer(dev->dev_id, dev, &dma->dma_buf_read, &dma->dma_buf_read_dev, FROM_DEV, TLKM_DMA_BUF_SZ);
    if (!IS_ERR(dma->regs)) {
	   iounmap(dma->regs);
    }
	memset(dma, 0, sizeof(*dma));
	DEVLOG(dma->dev_id, TLKM_LF_DMA, "deinitialized DMA engine");
}

ssize_t tlkm_dma_copy_to(struct dma_engine *dma, dev_addr_t dev_addr, const void __user *usr_addr, size_t len)
{
	struct tlkm_device *dev = dma->dev;
	size_t cpy_sz = len;
	ssize_t t_id;
	while (len > 0) {
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "outstanding bytes: %zd - usr_addr = 0x%px, dev_addr = 0x%px",
		       len, usr_addr, (void *)dev_addr);
		if ((dev_addr % dma->alignment) != 0) {
			DEVERR(dma->dev_id, "Transfer is not properly aligned for dma engine. All transfers have to be aligned to %d bytes.", dma->alignment);
			return -EAGAIN;
		}
		cpy_sz = len < TLKM_DMA_BUF_SZ ? len : TLKM_DMA_BUF_SZ;
		dma->ops.buffer_cpu(dev->dev_id, dev, &dma->dma_buf_write, &dma->dma_buf_write_dev, TO_DEV, cpy_sz);
		if (copy_from_user(dma->dma_buf_write, usr_addr, cpy_sz)) {
			DEVERR(dma->dev_id, "could not copy data from user");
			return -EAGAIN;
		} else {
			dma->ops.buffer_dev(dev->dev_id, dev, &dma->dma_buf_write, &dma->dma_buf_write_dev, TO_DEV, cpy_sz);
			t_id = dma->ops.copy_to(dma, dev_addr, dma->dma_buf_write_dev, cpy_sz);
			if (wait_event_interruptible(dma->wq, atomic64_read(&dma->wq_processed) >= t_id)) {
				WRN("got killed while hanging in waiting queue");
				return -EACCES;
			}
			usr_addr	+= cpy_sz;
			dev_addr	+= cpy_sz;
			len		-= cpy_sz;
		}
	}
	tlkm_perfc_dma_writes_add(dma->dev_id, len);
	return len;
}

ssize_t tlkm_dma_copy_from(struct dma_engine *dma, void __user *usr_addr, dev_addr_t dev_addr, size_t len)
{
	struct tlkm_device *dev = dma->dev;
	size_t cpy_sz = len;
	ssize_t t_id;
	while (len > 0) {
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "outstanding bytes: %zd - usr_addr = 0x%px, dev_addr = 0x%px",
		       len, usr_addr, (void *)dev_addr);
		if ((dev_addr % dma->alignment) != 0) {
			DEVERR(dma->dev_id, "Transfer is not properly aligned for dma engine. All transfers have to be aligned to %d bytes.", dma->alignment);
			return -EAGAIN;
		}
		cpy_sz = len < TLKM_DMA_BUF_SZ ? len : TLKM_DMA_BUF_SZ;
		dma->ops.buffer_dev(dev->dev_id, dev, &dma->dma_buf_read, &dma->dma_buf_read_dev, FROM_DEV, cpy_sz);
		t_id = dma->ops.copy_from(dma, dma->dma_buf_read_dev, dev_addr, cpy_sz);
		if (wait_event_interruptible(dma->rq, atomic64_read(&dma->rq_processed) >= t_id)) {
			DEVWRN(dma->dev_id, "got killed while hanging in waiting queue");
			return -EACCES;
		}
		dma->ops.buffer_cpu(dev->dev_id, dev, &dma->dma_buf_read, &dma->dma_buf_read_dev, FROM_DEV, cpy_sz);
		if (copy_to_user(usr_addr, dma->dma_buf_read, cpy_sz)) {
			DEVERR(dma->dev_id, "could not copy data to user");
			return -EAGAIN;
		}
		usr_addr	+= cpy_sz;
		dev_addr	+= cpy_sz;
		len		-= cpy_sz;
	}
	tlkm_perfc_dma_reads_add(dma->dev_id, len);
	return len;
}
