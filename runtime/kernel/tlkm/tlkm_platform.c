#include <linux/io.h>
#include <linux/slab.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include "tlkm_device.h"
#include "tlkm_platform.h"
#include "tlkm_logging.h"
#include "user/tlkm_device_ioctl_cmds.h"

#define AWS_EC2_VENDOR_ID	0x1D0F
#define AWS_EC2_DEVICE_ID	0xF000

static int aws_ec2_configure_axi_intc(struct tlkm_device *dev, struct platform_mmap *mmap)
{
	struct platform *p = &dev->cls->platform;
	uint32_t val;
	int i;
	void* __iomem intc_base;

	for (i = 0; i < 4; i++) {
		intc_base = mmap->plat + 0x500000 + i * 0x10000 - p->plat.base;

		val = ioread32(intc_base + 0x08);
		if (val) {
			DEVLOG(dev->dev_id, TLKM_LF_DEVICE,  "AXI interrupt controller %d already enabled or not found", i);
		} else {
			DEVLOG(dev->dev_id, TLKM_LF_DEVICE,  "Enable AXI interrupt controller %d", i);

			// set interrupt enable register (try to enable all interrupts)
			iowrite32(0xffffffff, intc_base + 0x08);
			// set master enable register (master enable + hardware interrupt enable)
			iowrite32(0xffffffff, intc_base + 0x1c);
			wmb();

			val = ioread32(intc_base + 0x08);
			if (!val) {
				DEVWRN(dev->dev_id, "AXI interrupt controller %d: No interrupt enabled", i);
			} else {
				DEVLOG(dev->dev_id, TLKM_LF_DEVICE,  "AXI interrupt controller %d enabled, IER = %x", i, val);
			}
		}
	}
	return 0;
}

int tlkm_platform_mmap_init(struct tlkm_device *dev, struct platform_mmap *mmap)
{
	int retval = 0;
	u32 magic_id = 0;
	struct platform *p = &dev->cls->platform;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for architecture",
			(void *)(dev->base_offset + p->arch.base),
			(void *)(dev->base_offset + p->arch.high));
	mmap->arch = ioremap_nocache(dev->base_offset + p->arch.base, p->arch.size);
	if (! mmap->arch) {
		DEVERR(dev->dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)(dev->base_offset + p->arch.base),
				(void *)(dev->base_offset + p->arch.high));
		retval = -ENOSPC;
		goto err_arch;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for platform",
			(void *)(dev->base_offset + p->plat.base),
			(void *)(dev->base_offset + p->plat.high));
	mmap->plat = ioremap_nocache(dev->base_offset + p->plat.base, p->plat.size);
	if (! mmap->plat) {
		DEVERR(dev->dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)(dev->base_offset + p->plat.base),
				(void *)(dev->base_offset + p->plat.high));
		retval = -ENOSPC;
		goto err_plat;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for status",
			(void *)(dev->base_offset + p->status.base),
			(void *)(dev->base_offset + p->status.high));
	mmap->status = ioremap_nocache(dev->base_offset + p->status.base, p->status.size);
	if (! mmap->status) {
		DEVERR(dev->dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)(dev->base_offset + p->status.base),
				(void *)(dev->base_offset + p->status.high));
		retval = -ENOSPC;
		goto err_status;
	}

	if (dev->vendor_id == AWS_EC2_VENDOR_ID && dev->product_id == AWS_EC2_DEVICE_ID) {
		retval = aws_ec2_configure_axi_intc(dev, mmap);
		if (retval) {
			goto err_status;
		}
	}

	magic_id = ioread32(mmap->status);
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,  "magic_id = 0x%08lx", (ulong)magic_id);
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
			"I/O mapped all registers successfully: AR = 0x%px, PL = 0x%px, ST=0x%px",
			mmap->arch, mmap->plat, mmap->status);
	return retval;

err_status:
	iounmap(mmap->plat);
	mmap->plat = NULL;
err_plat:
	iounmap(mmap->arch);
	mmap->arch = NULL;
err_arch:
	return retval;
}

void tlkm_platform_mmap_exit(struct tlkm_device *dev, struct platform_mmap *mmap)
{
	iounmap(mmap->status);
	mmap->status = NULL;
	iounmap(mmap->plat);
	mmap->plat = NULL;
	iounmap(mmap->arch);
	mmap->arch = NULL;
	DEVLOG(dev->dev_id, TLKM_LF_PLATFORM, "unmapped all I/O regions of '%s'", dev->name);
}

inline
void __iomem *addr2map(struct tlkm_device *dev, dev_addr_t const addr)
{
	struct platform *p = &dev->cls->platform;
	void __iomem *ptr = NULL;
	BUG_ON(! p);
	if (IS_BETWEEN(addr, p->arch.base, p->arch.high)) {
		ptr = dev->mmap.arch + (addr - p->arch.base);
	} else if (IS_BETWEEN(addr, p->plat.base, p->plat.high)) {
		ptr = dev->mmap.plat + (addr - p->plat.base);
	} else if (IS_BETWEEN(addr, p->status.base, p->status.high)) {
		ptr = dev->mmap.status + (addr - p->status.base);
	}
	return ptr;
}

long tlkm_platform_read(struct tlkm_device *dev, struct tlkm_copy_cmd *cmd)
{
	long ret = -ENXIO;
	void __iomem *ptr = NULL;
	void *buf = NULL;
	if (! (ptr = addr2map(dev, cmd->dev_addr))) {
		DEVERR(dev->dev_id, "invalid address: %pad", &cmd->dev_addr);
		return -ENXIO;
	}
	buf = kzalloc(cmd->length, GFP_ATOMIC);
	memcpy_fromio(buf, ptr, cmd->length);
	if ((ret = copy_to_user((u32 __user *)cmd->user_addr, buf, cmd->length))) {
		DEVERR(dev->dev_id, "could not copy all bytes from 0x%px to user space 0x%px: %ld",
				buf, cmd->user_addr, ret);
		ret = -EAGAIN;
	}
	kfree(buf);
	tlkm_perfc_total_ctl_reads_add(dev->dev_id, cmd->length);
	return ret;
}

long tlkm_platform_write(struct tlkm_device *dev, struct tlkm_copy_cmd *cmd)
{
	long ret = -ENXIO;
	void __iomem *ptr = NULL;
	void *buf = NULL;
	if (! (ptr = addr2map(dev, cmd->dev_addr))) {
		DEVERR(dev->dev_id, "invalid address: %pad", &cmd->dev_addr);
		return -ENXIO;
	}
	buf = kzalloc(cmd->length, GFP_ATOMIC);
	if ((ret = copy_from_user(buf, (u32 __user *)cmd->user_addr, cmd->length))) {
		DEVERR(dev->dev_id, "could not copy all bytes from 0x%px to user space 0x%px: %ld",
				buf, cmd->user_addr, ret);
		ret = -EAGAIN;
		goto err;
	}
	memcpy_toio(ptr, buf, cmd->length);
	tlkm_perfc_total_ctl_writes_add(dev->dev_id, cmd->length);
err:
	kfree(buf);
	return ret;
}
