#ifndef TLKM_STATUS_H__
#define TLKM_STATUS_H__

#include <linux/bug.h>
#include "platform_components.h"
#include "tlkm_types.h"
struct tlkm_device;

#define	MAX_COMP			PLATFORM_COMPONENT_DMA3
#define NUM_COMP			(PLATFORM_COMPONENT_DMA3 + 1)

struct tlkm_status {
	struct tlkm_device 		*parent;
	dev_addr_t			component[NUM_COMP];
};

int  tlkm_status_init(struct tlkm_status *sta, struct tlkm_device *dev, dev_addr_t base);
void tlkm_status_exit(struct tlkm_status *sta, struct tlkm_device *dev);

static inline
dev_addr_t tlkm_status_get_component_base(struct tlkm_status *sta, platform_component_t c)
{
	BUG_ON(! sta->parent);
	BUG_ON(c >= NUM_COMP);
	return sta->component[c];
}

#endif /* TLKM_STATUS_H__ */
