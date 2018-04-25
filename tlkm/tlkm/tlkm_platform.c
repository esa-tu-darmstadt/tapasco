#include <linux/io.h>
#include "tlkm_device.h"
#include "tlkm_platform.h"
#include "tlkm_logging.h"

int tlkm_platform_mmap_init(struct tlkm_device *dev, struct platform_mmap *mmap)
{
	int retval = 0;
	u32 magic_id = 0;
	struct platform *p = &dev->cls->platform;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for architecture",
			(void *)p->arch.base, (void *)p->arch.high);
	mmap->arch = ioremap_nocache(p->arch.base, p->arch.size);
	if (! mmap->arch) {
		DEVERR(dev->dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)p->arch.base, (void *)p->arch.high);
		retval = -ENOSPC;
		goto err_arch;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for platform",
			(void *)p->plat.base, (void *)p->plat.high);
	mmap->plat = ioremap_nocache(p->plat.base, p->plat.size);
	if (! mmap->plat) {
		DEVERR(dev->dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)p->plat.base, (void *)p->plat.high);
		retval = -ENOSPC;
		goto err_plat;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for status",
			(void *)p->status.base, (void *)p->status.high);
	mmap->status = ioremap_nocache(p->status.base, p->status.size);
	if (! mmap->status) {
		DEVERR(dev->dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)p->status.base, (void *)p->status.high);
		retval = -ENOSPC;
		goto err_status;
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
