#ifndef TLKM_CLASS_H__
#define TLKM_CLASS_H__

#include <linux/interrupt.h>
#include "tlkm_types.h"
#include "tlkm_platform.h"

#define TLKM_CLASS_NAME_LEN				32

struct tlkm_device;
struct tlkm_class;

typedef int (*tlkm_class_create_f)(struct tlkm_device *, void *data);
typedef void(*tlkm_class_destroy_f)(struct tlkm_device *);
typedef int (*tlkm_class_init_subsystems_f)(struct tlkm_device *, void *data);
typedef void(*tlkm_class_exit_subsystems_f)(struct tlkm_device *);
typedef int (*tlkm_class_probe_f)(struct tlkm_class *);
typedef void(*tlkm_class_remove_f)(struct tlkm_class *);


typedef long (*tlkm_device_ioctl_f)(struct tlkm_device *, unsigned int ioctl, unsigned long data);
typedef int  (*tlkm_device_pirq_f) (struct tlkm_device *, int irq_no, irq_handler_t h, void *data);
typedef void (*tlkm_device_rirq_f) (struct tlkm_device *, int irq_no);

struct tlkm_class {
	char 				name[TLKM_CLASS_NAME_LEN];
	tlkm_class_create_f		create;
	tlkm_class_destroy_f		destroy;
	tlkm_class_init_subsystems_f	init_subsystems;
	tlkm_class_exit_subsystems_f	exit_subsystems;
	tlkm_class_probe_f		probe;
	tlkm_class_remove_f		remove;
	tlkm_device_ioctl_f		ioctl;		/* ioctl implementation */
	tlkm_device_pirq_f		pirq;		/* request platform IRQ */
	tlkm_device_rirq_f		rirq;		/* release platform IRQ */
	size_t				npirqs;		/* number of platform interrupts */
	struct platform			platform;	/* register space definitions */
	void				*private_data;
};

#endif /* TLKM_CLASS_H__ */
