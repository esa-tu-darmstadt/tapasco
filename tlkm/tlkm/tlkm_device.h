#ifndef TLKM_DEVICE_H__
#define TLKM_DEVICE_H__

#include <linux/pci.h>
#include <linux/list.h>
#include <linux/mutex.h>
#include <linux/miscdevice.h>
#include "tlkm_types.h"
#include "tlkm_perfc.h"
#include "tlkm_access.h"
#include "dma/tlkm_dma.h"

#define TLKM_DEVICE_NAME_LEN				30
#define TLKM_DEVICE_MAX_DMA_ENGINES			4

struct tlkm_device;

struct tlkm_device_inst {
	dev_id_t 		dev_id;
	size_t			ref_cnt[TLKM_ACCESS_TYPES];
	struct tlkm_control	*ctrl;
	struct dma_engine	dma[TLKM_DEVICE_MAX_DMA_ENGINES];
#ifndef NPERFC
	struct miscdevice	perfc_dev;
#endif
	void 			*private_data;
};


typedef irqreturn_t (*intr_handler_f)(int, void*);

typedef int  (*tlkm_device_init_f)(struct tlkm_device_inst *);
typedef void (*tlkm_device_exit_f)(struct tlkm_device_inst *);
typedef long (*tlkm_device_ioctl_f)(struct tlkm_device_inst *, unsigned int ioctl, unsigned long data);
typedef int  (*tlkm_device_mmap_f)(struct tlkm_device_inst *, struct vm_area_struct *vm);
typedef int  (*tlkm_device_pirq_f)(struct tlkm_device *, int irq_no, intr_handler_f h);
typedef void (*tlkm_device_rirq_f)(struct tlkm_device *, int irq_no);

struct tlkm_device {
	struct list_head 	device; 	/* this device in tlkm_bus */
	struct mutex 		mtx;
	dev_id_t		dev_id;
	char 			name[TLKM_DEVICE_NAME_LEN];
	int 			vendor_id;
	int 			product_id;
	tlkm_device_init_f 	init;
	tlkm_device_exit_f 	exit;
	tlkm_device_ioctl_f	ioctl;
	tlkm_device_mmap_f	mmap;
	tlkm_device_pirq_f	pirq;		/* request platform IRQ */
	tlkm_device_rirq_f	rirq;		/* release platform IRQ */
	dev_addr_t		base_offset;	/* physical base offset of bitstream */
	dev_addr_t		status_base;	/* physical offset of status core in bitstream */
	size_t			numpirqs;	/* number of available platform interrupts */
	struct tlkm_device_inst *inst;
};
typedef struct tlkm_device tlkm_device_t;

int  tlkm_device_create(struct tlkm_device *pdev, tlkm_access_t access);
void tlkm_device_destroy(struct tlkm_device *pdev, tlkm_access_t access);
void tlkm_device_remove_all(struct tlkm_device *pdev);

static inline
int tlkm_device_request_platform_irq(struct tlkm_device *dev, int irq_no, intr_handler_f h)
{
	return dev->pirq(dev, irq_no, h);
}

static inline
void tlkm_device_release_platform_irq(struct tlkm_device *dev, int irq_no)
{
	dev->rirq(dev, irq_no);
}

#endif /* TLKM_DEVICE_H__ */
