#ifndef TLKM_STATUS_H__
#define TLKM_STATUS_H__

#include <linux/bug.h>
#include <status_core.pb.h>
#include "platform_components.h"
#include "tlkm_types.h"
struct tlkm_device;

typedef tapasco_status_Status tlkm_status;

#define TLKM_COMPONENT_MAX 16
#define TLKM_COMPONENTS_NAME_MAX 32

typedef struct tlkm_component {
    char name[TLKM_COMPONENTS_NAME_MAX];
    dev_addr_t offset;
} tlkm_component_t;

int  tlkm_status_init(tlkm_status *sta, struct tlkm_device *dev, void __iomem *status, size_t status_size);
void tlkm_status_exit(tlkm_status *sta, struct tlkm_device *dev);

dev_addr_t tlkm_status_get_component_base(struct tlkm_device *dev, const char* c);

#endif /* TLKM_STATUS_H__ */
