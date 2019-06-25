#ifndef TLKM_BUS_H__
#define TLKM_BUS_H__

#include "tlkm_device.h"

struct tlkm_bus;
struct tlkm_class;

int  tlkm_bus_init(void);
void tlkm_bus_exit(void);

struct tlkm_device *tlkm_bus_new_device(struct tlkm_class *cls,
		int vendor_id,
		int product_id,
		void *data);
void tlkm_bus_delete_device(struct tlkm_device *dev);

void tlkm_bus_enumerate(void);

size_t tlkm_bus_num_devices(void);
struct tlkm_device *tlkm_bus_get_device(size_t idx);

#endif /* TLKM_BUS_H__ */
