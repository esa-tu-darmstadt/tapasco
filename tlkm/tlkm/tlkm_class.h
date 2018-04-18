#ifndef TLKM_CLASS_H__
#define TLKM_CLASS_H__

#include "tlkm_device.h"

#define TLKM_CLASS_NAME_LEN				32

typedef int (*tlkm_class_create_f)(struct tlkm_device *);
typedef void(*tlkm_class_destroy_f)(struct tlkm_device *);
typedef int (*tlkm_class_probe_f)(struct tlkm_class *);
typedef void(*tlkm_class_remove_f)(struct tlkm_class *);

struct tlkm_class {
	char 				name[TLKM_CLASS_NAME_LEN];
	tlkm_class_create_f		create;
	tlkm_class_destroy_f		destroy;
	tlkm_class_probe_f		probe;
	tlkm_class_remove_f		remove;
	dev_addr_t			status_base;	/* physical offset of status core in bitstream */
	size_t				npirqs;		/* number of platform interrupts */
	void				*private_data;
};

#endif /* TLKM_CLASS_H__ */
