#ifndef TLKM_DEVICE_H__
#define TLKM_DEVICE_H__

#include <linux/pci.h>
#include <linux/list.h>
#include <linux/mutex.h>
#include <linux/miscdevice.h>
#include "tlkm_types.h"
#include "tlkm_perfc.h"
#include "tlkm_access.h"
#include "tlkm_status.h"
#include "dma/tlkm_dma.h"

#define TLKM_DEVICE_NAME_LEN				30
#define TLKM_DEVICE_MAX_DMA_ENGINES			4

struct tlkm_device;

typedef irqreturn_t (*intr_handler_f)(int, void*);

typedef long (*tlkm_device_ioctl_f)(struct tlkm_device *, unsigned int ioctl, unsigned long data);
typedef int  (*tlkm_device_mmap_f) (struct tlkm_device *, struct vm_area_struct *vm);
typedef int  (*tlkm_device_pirq_f) (struct tlkm_device *, int irq_no, intr_handler_f h);
typedef void (*tlkm_device_rirq_f) (struct tlkm_device *, int irq_no);

struct tlkm_device {
	struct list_head 	device; 	/* this device in tlkm_bus */
	struct mutex 		mtx;
	struct tlkm_class	*cls;		/* class of the device */
	dev_id_t		dev_id;		/* id of the device in tlkm_bus */
	char 			name[TLKM_DEVICE_NAME_LEN];
	int 			vendor_id;
	int 			product_id;
	dev_addr_t		base_offset;	/* physical base offset of bitstream */

	tlkm_device_ioctl_f	ioctl;		/* ioctl implementation */
	tlkm_device_mmap_f	mmap;		/* mmap implementation */
	tlkm_device_pirq_f	pirq;		/* request platform IRQ */
	tlkm_device_rirq_f	rirq;		/* release platform IRQ */

	size_t			ref_cnt[TLKM_ACCESS_TYPES];
	struct tlkm_status	status;		/* address map information */
	struct tlkm_control	*ctrl;		/* main device file */
	struct dma_engine	dma[TLKM_DEVICE_MAX_DMA_ENGINES];
#ifndef NPERFC
	struct miscdevice	perfc_dev;	/* performance counter device */
#endif
	void 			*private_data;	/* implementation-specific data */
};

int  tlkm_device_init(struct tlkm_device *pdev);
int  tlkm_device_acquire(struct tlkm_device *pdev, tlkm_access_t access);
void tlkm_device_release(struct tlkm_device *pdev, tlkm_access_t access);
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
