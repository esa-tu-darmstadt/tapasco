#ifndef TLKM_BUS_H__
#define TLKM_BUS_H__

#include "tlkm_device.h"

struct tlkm_bus;

int tlkm_bus_init(void);
void tlkm_bus_exit(void);

int tlkm_bus_enumerate(void);

void tlkm_bus_add_device(struct tlkm_device *pdev);
void tlkm_bus_del_device(struct tlkm_device *pdev);

size_t tlkm_bus_num_devices(void);
struct tlkm_device *tlkm_bus_get_device(size_t idx);

inline static
int  tlkm_bus_create_device(dev_id_t dev_id, tlkm_access_t access)
{
	return tlkm_device_create(tlkm_bus_get_device(dev_id), access);
}

inline static
void tlkm_bus_destroy_device(dev_id_t dev_id, tlkm_access_t access)
{
	tlkm_device_destroy(tlkm_bus_get_device(dev_id), access);
}

#endif /* TLKM_BUS_H__ */
