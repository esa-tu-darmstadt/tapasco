#ifndef TLKM_DEVICE_H__
#define TLKM_DEVICE_H__

#include <linux/list.h>
#include <linux/mutex.h>
#include <linux/miscdevice.h>
#include "tlkm_types.h"
#include "tlkm_perfc.h"
#include "tlkm_access.h"

#define TLKM_DEVICE_NAME_LEN				30

struct tlkm_device_inst {
	dev_id_t 		dev_id;
	size_t			ref_cnt[TLKM_ACCESS_TYPES];
	struct tlkm_control	*ctrl;
#ifndef NPERFC
	struct miscdevice	perfc_dev;
#endif
	void 			*private_data;
};

typedef int  (*tlkm_device_init_f)(struct tlkm_device_inst *);
typedef void (*tlkm_device_exit_f)(struct tlkm_device_inst *);

struct tlkm_device {
	struct list_head 	device; /* this device in tlkm_bus */
	struct mutex 		mtx;
	dev_id_t		dev_id;
	char 			name[TLKM_DEVICE_NAME_LEN];
	int 			vendor_id;
	int 			product_id;
	tlkm_device_init_f 	init;
	tlkm_device_exit_f 	exit;
	struct tlkm_device_inst *inst;
};
typedef struct tlkm_device tlkm_device_t;

int  tlkm_device_create(struct tlkm_device *pdev, tlkm_access_t access);
void tlkm_device_destroy(struct tlkm_device *pdev, tlkm_access_t access);

#endif /* TLKM_DEVICE_H__ */
