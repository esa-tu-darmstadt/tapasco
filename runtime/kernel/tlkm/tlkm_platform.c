#include <linux/io.h>
#include <linux/slab.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include "tlkm_device.h"
#include "tlkm_platform.h"
#include "tlkm_logging.h"
#include "user/tlkm_device_ioctl_cmds.h"

int tlkm_platform_status_init(struct tlkm_device *dev,
			      struct platform_mmap *mmap)
{
	int retval = 0;
	struct platform *p = &dev->cls->platform;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "I/O mapping 0x%px-0x%px for status",
	       (void *)(dev->base_offset + p->status.base),
	       (void *)(dev->base_offset + p->status.high));
	mmap->status = ioremap_nocache(dev->base_offset + p->status.base,
				       p->status.size);
	if (!mmap->status) {
		DEVERR(dev->dev_id,
		       "could not ioremap the AXI register space at 0x%px-0x%px",
		       (void *)(dev->base_offset + p->status.base),
		       (void *)(dev->base_offset + p->status.high));
		retval = -ENOSPC;
		goto err_status;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "I/O mapped status register successfully: ST=0x%px",
	       mmap->status);
	return retval;

err_status:
	return retval;
}

void tlkm_platform_status_exit(struct tlkm_device *dev,
			       struct platform_mmap *mmap)
{
	if (mmap->status) {
		iounmap(mmap->status);
		mmap->status = NULL;
	}
	DEVLOG(dev->dev_id, TLKM_LF_PLATFORM,
	       "unmapped status I/O regions of '%s'", dev->name);
}

int tlkm_platform_mmap_init(struct tlkm_device *dev, struct platform_mmap *mmap)
{
	int retval = 0;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "I/O mapping 0x%px-0x%px for architecture",
	       (void *)(dev->base_offset + dev->arch.base),
	       (void *)(dev->base_offset + dev->arch.high));
	mmap->arch = ioremap_nocache(dev->base_offset + dev->arch.base,
				     dev->arch.size);
	if (!mmap->arch) {
		DEVERR(dev->dev_id,
		       "could not ioremap the AXI register space at 0x%px-0x%px",
		       (void *)(dev->base_offset + dev->arch.base),
		       (void *)(dev->base_offset + dev->arch.high));
		retval = -ENOSPC;
		goto err_arch;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "I/O mapping 0x%px-0x%px for platform",
	       (void *)(dev->base_offset + dev->plat.base),
	       (void *)(dev->base_offset + dev->plat.high));
	mmap->plat = ioremap_nocache(dev->base_offset + dev->plat.base,
				     dev->plat.size);
	if (!mmap->plat) {
		DEVERR(dev->dev_id,
		       "could not ioremap the AXI register space at 0x%px-0x%px",
		       (void *)(dev->base_offset + dev->plat.base),
		       (void *)(dev->base_offset + dev->plat.high));
		retval = -ENOSPC;
		goto err_plat;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "I/O mapped all registers successfully: AR = 0x%px, PL = 0x%px",
	       mmap->arch, mmap->plat);
	return retval;

err_plat:
	iounmap(mmap->arch);
	mmap->arch = NULL;
err_arch:
	return retval;
}

void tlkm_platform_mmap_exit(struct tlkm_device *dev,
			     struct platform_mmap *mmap)
{
	if (mmap->plat) {
		iounmap(mmap->plat);
		mmap->plat = NULL;
	}
	if (mmap->arch) {
		iounmap(mmap->arch);
		mmap->arch = NULL;
	}
	DEVLOG(dev->dev_id, TLKM_LF_PLATFORM,
	       "unmapped remaining I/O regions of '%s'", dev->name);
}

inline ulong addr2map_off(struct tlkm_device *dev, dev_addr_t const addr)
{
	struct platform *p = &dev->cls->platform;
	ulong ptr = -1;
	BUG_ON(!p);
	if (addr == 0) {
		ptr = p->status.base;
	} else if (addr == 4096) {
		ptr = dev->arch.base;
	} else if (addr == 8192) {
		ptr = dev->plat.base;
	}
	return ptr;
}

inline void __iomem *addr2map(struct tlkm_device *dev, dev_addr_t const addr)
{
	struct platform *p = &dev->cls->platform;
	void __iomem *ptr = NULL;
	BUG_ON(!p);
	if (addr == 0) {
		ptr = dev->mmap.status;
	} else if (addr == 4096) {
		ptr = dev->mmap.arch;
	} else if (addr == 8192) {
		ptr = dev->mmap.plat;
	}
	return ptr;
}

long tlkm_platform_read(struct tlkm_device *dev, struct tlkm_copy_cmd *cmd)
{
	long ret = -ENXIO;
	void __iomem *ptr = NULL;
	void *buf = NULL;
	if (!(ptr = addr2map(dev, cmd->dev_addr))) {
		DEVERR(dev->dev_id, "invalid address: %pad", &cmd->dev_addr);
		return -ENXIO;
	}
	buf = kzalloc(cmd->length, GFP_ATOMIC);
	memcpy_fromio(buf, ptr, cmd->length);
	if ((ret = copy_to_user((u32 __user *)cmd->user_addr, buf,
				cmd->length))) {
		DEVERR(dev->dev_id,
		       "could not copy all bytes from 0x%px to user space 0x%px: %ld",
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
	if (!(ptr = addr2map(dev, cmd->dev_addr))) {
		DEVERR(dev->dev_id, "invalid address: %pad", &cmd->dev_addr);
		return -ENXIO;
	}
	buf = kzalloc(cmd->length, GFP_ATOMIC);
	if ((ret = copy_from_user(buf, (u32 __user *)cmd->user_addr,
				  cmd->length))) {
		DEVERR(dev->dev_id,
		       "could not copy all bytes from 0x%px to user space 0x%px: %ld",
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
