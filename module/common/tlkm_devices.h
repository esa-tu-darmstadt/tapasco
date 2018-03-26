#ifndef TLKM_DEVICE_H__
#define TLKM_DEVICE_H__

#define TLKM_DEVICE_NAME_LEN				100

struct tlkm_device;
typedef struct tlkm_device tlkm_device_t;
int  (*tlkm_device_init_f)(tlkm_device_t **pdev);
void (*tlkm_device_exit_f)(tlkm_device_t *dev);

struct tlkm_device {
	char name[100];
	int vendor_id;
	int product_id;
	tlkm_device_init_f init;
	tlkm_device_exit_f exit;
};

ssize_t tlkm_devices_enumerate(tlkm_device_t **devs);

#endif /* TLKM_DEVICE_H__ */
