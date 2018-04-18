#include <linux/gfp.h>
#include <linux/uaccess.h>
#include "tlkm_dma.h"
#include "tlkm_logging.h"
#include "blue_dma.h"
#include "dual_dma.h"

#define REG_ID 						0x18
#define DMA_SZ						0x10000

static const struct dma_operations dma_ops[] = {
	[DMA_USED_DUAL] = {
		.intr_read	= dual_dma_intr_handler_dma, // Dual DMA can not read and write in parallel
		.intr_write	= dual_dma_intr_handler_dma,
		.copy_from	= dual_dma_copy_from,
		.copy_to	= dual_dma_copy_to,
	},
	[DMA_USED_BLUE] = {
		.intr_read	= blue_dma_intr_handler_read,
		.intr_write	= blue_dma_intr_handler_write,
		.copy_from	= blue_dma_copy_from,
		.copy_to	= blue_dma_copy_to,
	},
};

int tlkm_dma_init(struct dma_engine *dma, dev_id_t dev_id, void *base, int irq_no)
{
	uint64_t id;
	int i, ret = 0;
	BUG_ON(! dma);
	DEVLOG(dev_id, TLKM_LF_DMA, "initializing DMA engine 0x%08llx (#%d) ...", (u64)base, irq_no);

	DEVLOG(dev_id, TLKM_LF_DMA, "I/O remapping 0x%08llx - 0x%08llx...", (u64)base, (u64)base + DMA_SZ - 1);
	dma->regs = ioremap_nocache((resource_size_t)base, DMA_SZ);
	if (IS_ERR(dma->regs)) {
		DEVERR(dev_id, "failed to map 0x%08llx - 0x%08llx: %ld",
				(u64)base, (u64)base + DMA_SZ - 1, PTR_ERR(dma->regs));
		return PTR_ERR(dma->regs);
	}

	DEVLOG(dev_id, TLKM_LF_DMA, "allocating DMA buffers of %zd bytes ...", TLKM_DMA_BUF_SZ);
	for (i = 0; i < TLKM_DMA_BUFS; ++i) {
		dma->dma_buf[i] = kzalloc(TLKM_DMA_BUF_SZ, GFP_KERNEL | GFP_DMA);
		if (IS_ERR(dma->dma_buf[i])) {
			ret = PTR_ERR(dma->dma_buf[i]);
			goto err_dma_bufs;
		}
	}

	DEVLOG(dev_id, TLKM_LF_DMA, "detecting DMA engine type ...");
	id = *(u64 *)(dma->regs + REG_ID);
	if ((id & 0xFFFFFFFF) == 0xE5A0023) {
		dma->dma_used = DMA_USED_BLUE;
		DEVLOG(dev_id, TLKM_LF_DMA, "detected BlueDMA");
		DEVLOG(dev_id, TLKM_LF_DMA, "PCIe beats per burst: %u", (uint8_t)(id >> 32));
		DEVLOG(dev_id, TLKM_LF_DMA, "FPGA beats per burst: %u", (uint8_t)(id >> 40));
		DEVLOG(dev_id, TLKM_LF_DMA, "smallest alignment: %u", (uint8_t)(id >> 48));
	} else {
		dma->dma_used = DMA_USED_DUAL;
		DEVLOG(dev_id, TLKM_LF_DMA, "detected DualDMA");
	}
	dma->ops = dma_ops[dma->dma_used];
	init_waitqueue_head(&dma->rq);
	init_waitqueue_head(&dma->wq);
	mutex_init(&dma->regs_mutex);
	mutex_init(&dma->rq_mutex);
	mutex_init(&dma->wq_mutex);
	dma->dev_id = dev_id;
	dma->base = base;
	dma->irq_no = irq_no;
	atomic64_set(&dma->rq_processed, 0);
	atomic64_set(&dma->wq_processed, 0);
	return 0;

err_dma_bufs:
	for (; i >= 0; --i)
		kfree(dma->dma_buf[i]);
	iounmap(dma->regs);
	return ret;
}

void tlkm_dma_exit(struct dma_engine *dma)
{
	int i;
	for (i = 0; i < TLKM_DMA_BUFS; ++i)
		kfree(dma->dma_buf[i]);
	iounmap(dma->regs);
	memset(dma, 0, sizeof(*dma));
	DEVLOG(dma->dev_id, TLKM_LF_DMA, "deinitialized DMA engine");
}

ssize_t tlkm_dma_copy_to(struct dma_engine *dma, dev_addr_t dev_addr, const void __user *usr_addr, size_t len)
{
	size_t cpy_sz = len;
	ssize_t t_id;
	while (len > 0) {
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "outstanding bytes: %zd - usr_addr = 0x%08llx, dev_addr = 0x%08llx",
				len, (u64)usr_addr, (u64)dev_addr);
		cpy_sz = len < TLKM_DMA_BUF_SZ ? len : TLKM_DMA_BUF_SZ;
		if (copy_from_user(dma->dma_buf[0], usr_addr, cpy_sz)) {
			DEVERR(dma->dev_id, "could not copy data from user");
			return -EAGAIN;
		} else {
			t_id = dma->ops.copy_to(dma, dev_addr, dma->dma_buf[0], cpy_sz);
			if (wait_event_interruptible(dma->rq, atomic64_read(&dma->wq_processed) > t_id)) {
				WRN("got killed while hanging in waiting queue");
				return -EACCES;
			}
			usr_addr	+= cpy_sz;
			dev_addr	+= cpy_sz;
			len		-= cpy_sz;
		}
	}
	return len;
}

ssize_t tlkm_dma_copy_from(struct dma_engine *dma, void __user *usr_addr, dev_addr_t dev_addr, size_t len)
{
	size_t cpy_sz = len;
	ssize_t t_id;
	while (len > 0) {
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "outstanding bytes: %zd - usr_addr = 0x%08llx, dev_addr = 0x%08llx",
				len, (u64)usr_addr, (u64)dev_addr);
		cpy_sz = len < TLKM_DMA_BUF_SZ ? len : TLKM_DMA_BUF_SZ;
		t_id = dma->ops.copy_from(dma, dma->dma_buf[1], dev_addr, cpy_sz);
		if (wait_event_interruptible(dma->rq, atomic64_read(&dma->rq_processed) > t_id)) {
			DEVWRN(dma->dev_id, "got killed while hanging in waiting queue");
			return -EACCES;
		}
		usr_addr	+= cpy_sz;
		dev_addr	+= cpy_sz;
		len		-= cpy_sz;
		if (copy_to_user(usr_addr, dma->dma_buf[1], cpy_sz)) {
			DEVERR(dma->dev_id, "could not copy data from user");
			return -EAGAIN;
		}
	}
	return len;
}
