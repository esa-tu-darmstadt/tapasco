#ifndef TLKM_DEVICE_H__
#define TLKM_DEVICE_H__

#include <linux/list.h>

#define TLKM_DEVICE_NAME_LEN				100

struct tlkm_device;
typedef struct tlkm_device tlkm_device_t;
typedef int  (*tlkm_device_init_f)(tlkm_device_t **);
typedef void (*tlkm_device_exit_f)(tlkm_device_t *);

struct tlkm_device {
	struct list_head device; /* this device in tlkm_bus */
	char name[100];
	int vendor_id;
	int product_id;
	tlkm_device_init_f init;
	tlkm_device_exit_f exit;
};

ssize_t tlkm_devices_enumerate(void);

#endif /* TLKM_DEVICE_H__ */
