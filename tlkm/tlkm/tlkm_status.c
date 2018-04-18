#include "tlkm_logging.h"
#include "tlkm_status.h"
#include "tlkm_device.h"

#define REG_OFFSET				0x1000
#define REG_SZ					(NUM_COMP * sizeof(dev_addr_t))

int tlkm_status_init(struct tlkm_status *sta, struct tlkm_device *dev, dev_addr_t base)
{
	int i;
	void __iomem *regs;
	BUG_ON(! dev);
	BUG_ON(! sta);
	DEVLOG(dev->dev_id, TLKM_LF_STATUS, "initializing platform address map from 0x%08llx ...", (u64)base);
	memset(sta, 0, sizeof(*sta));
	regs = ioremap_nocache(base + REG_OFFSET, REG_SZ);
	if (regs) {
		memcpy_fromio(sta->component, regs, REG_SZ);
		iounmap(regs);
		for (i = 0; i < NUM_COMP; ++i)
			DEVLOG(dev->dev_id, TLKM_LF_STATUS, "component[%d] = 0x%08llx", i, (u64)sta->component[i]);
		sta->parent = dev;
	} else {
		DEVERR(dev->dev_id, "failed to map 0x%08llx - 0x%08llx",
				(u64)(base + REG_OFFSET), (u64)(base + REG_OFFSET + REG_SZ));
		return -ENXIO;
	}
	return 0;
}

void tlkm_status_exit(struct tlkm_status *sta, struct tlkm_device *dev)
{
	memset(sta, 0, sizeof(*sta));
	DEVLOG(dev->dev_id, TLKM_LF_STATUS, "destroyed tlkm_status");
}
