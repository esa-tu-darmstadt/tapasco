#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/device.h>
#include <linux/version.h>
#include <linux/atomic.h>
#include "tlkm_logging.h"
#include "tlkm_control.h"
#include "pcie/pcie.h"
#include "pcie/pcie_irq.h"
#include "pcie/pcie_device.h"

#define _INTR(nr) 					\
void tlkm_pcie_slot_irq_work_ ## nr(struct work_struct *work) \
{ \
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)container_of(work, struct tlkm_pcie_device, irq_work[nr]); \
	BUG_ON(! dev->parent->ctrl); \
	tlkm_control_signal_slot_interrupt(dev->parent->ctrl, nr); \
} \
\
irqreturn_t tlkm_pcie_slot_irq_ ## nr(int irq, void *dev_id) 		\
{ 									\
	struct pci_dev *pdev = (struct pci_dev *)dev_id; \
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *) dev_get_drvdata(&pdev->dev); \
	struct platform *p = &dev->parent->cls->platform;\
	volatile uint32_t* msix_ack = (volatile uint32_t*) (dev->parent->mmap.plat + ((0x500000 + 0x8120) - p->plat.base)); \
	BUG_ON(! dev); \
	if (! schedule_work(&dev->irq_work[nr])) \
		tlkm_perfc_irq_error_already_pending_inc(dev->parent->dev_id); \
	tlkm_perfc_total_irqs_inc(dev->parent->dev_id); \
	msix_ack[0] = nr + pcie_cls.npirqs; \
	return IRQ_HANDLED; \
}

TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR

int pcie_irqs_init(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;

	int ret = 0, irqn, err[NUMBER_OF_INTERRUPTS] = { [0 ... NUMBER_OF_INTERRUPTS - 1] = 1 };
	BUG_ON(! dev);
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "registering %d interrupts ...", NUMBER_OF_INTERRUPTS);
#define _INTR(nr) \
	irqn = nr + pcie_cls.npirqs; \
	if ((err[nr] = request_irq(pci_irq_vector(pdev->pdev, irqn), \
			tlkm_pcie_slot_irq_ ## nr, \
			IRQF_EARLY_RESUME, \
			TLKM_PCI_NAME, \
			pdev->pdev))) { \
		DEVERR(dev->dev_id, "could not request interrupt %d: %d", irqn, err[nr]); \
		goto irq_error; \
	} else { \
		pdev->irq_mapping[irqn] = pci_irq_vector(pdev->pdev, irqn); \
		DEVLOG(dev->dev_id, TLKM_LF_IRQ, "interrupt line %d/%d assigned with return value %d", \
				irqn, pci_irq_vector(pdev->pdev, irqn), err[nr]); \
		INIT_WORK(&pdev->irq_work[nr], tlkm_pcie_slot_irq_work_ ## nr); \
	}
	TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR
	return 0;

irq_error:
#define _INTR(nr) \
	irqn = nr + pcie_cls.npirqs; \
	if (! err[nr]) { \
		free_irq(pdev->irq_mapping[irqn], pdev->pdev); \
		pdev->irq_mapping[irqn] = -1; \
	} else { \
		ret = err[nr]; \
	}
	TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR
	return ret;
}

void pcie_irqs_exit(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	int irqn;
#define _INTR(nr) \
	irqn = nr + pcie_cls.npirqs; \
	if (pdev->irq_mapping[irqn] != -1) { \
		DEVLOG(dev->dev_id, TLKM_LF_IRQ, "freeing interrupt %d with mappping %d", irqn, pdev->irq_mapping[irqn]); \
		free_irq(pdev->irq_mapping[irqn], pdev->pdev); \
		pdev->irq_mapping[irqn] = -1; \
	}
	TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "interrupts deactivated");
}

// *********************************
// begin aws ec2 interrupt handliing
// *********************************

uint32_t get_xdma_reg_addr(uint32_t target, uint32_t channel, uint32_t offset);

#define _INTR(nr) \
void aws_ec2_tlkm_pcie_slot_irq_work_ ## nr(struct work_struct *work) \
{ \
	int i; \
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)container_of(work, struct tlkm_pcie_device, irq_work[nr]); \
	struct platform *p = &dev->parent->cls->platform; \
	/*volatile uint32_t* interrupt_pending = (volatile uint32_t*) (dev->parent->mmap.plat + ((0x500000 + 0x00) - p->plat.base));*/ \
	/* read ISR (interrupt status register) */ \
	uint32_t isr = ioread32(dev->parent->mmap.plat + 0x500000 + nr * 0x10000 + 0x00 - p->plat.base); \
	BUG_ON(! dev->parent->ctrl); \
	for (i = 0; i < 32; i++) { \
		if (isr & (1 << i)) { \
			/*DEVLOG(dev->parent->dev_id, TLKM_LF_IRQ, "[ISR] bit %d set", i);*/ \
			/* write to IAR (interrupt ack register) */ \
			iowrite32(1 << i, dev->parent->mmap.plat + 0x500000 + nr * 0x10000 + 0x0C - p->plat.base); \
			tlkm_control_signal_slot_interrupt(dev->parent->ctrl, nr * 32 + i); \
		} \
	} \
} \
\
irqreturn_t aws_ec2_tlkm_pcie_slot_irq_ ## nr(int irq, void *dev_id) \
{ \
	struct pci_dev *pdev = (struct pci_dev *)dev_id; \
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *) dev_get_drvdata(&pdev->dev); \
	BUG_ON(! dev); \
	if (! schedule_work(&dev->irq_work[nr])) \
		tlkm_perfc_irq_error_already_pending_inc(dev->parent->dev_id); \
	tlkm_perfc_total_irqs_inc(dev->parent->dev_id); \
	return IRQ_HANDLED; \
} \

TLKM_AWS_EC2_SLOT_INTERRUPTS
#undef _INTR

int aws_ec2_pcie_irqs_init(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;

	int ret = 0, irqn, err[4] = { [0 ... 3] = 1 };

	BUG_ON(! dev);
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "registering %d interrupts ...", 4);
#define _INTR(nr) \
	irqn = nr + pcie_cls.npirqs; \
	if ((err[nr] = request_irq(pci_irq_vector(pdev->pdev, irqn), \
			aws_ec2_tlkm_pcie_slot_irq_ ## nr, \
			IRQF_EARLY_RESUME, \
			TLKM_PCI_NAME, \
			pdev->pdev))) { \
		DEVERR(dev->dev_id, "could not request interrupt %d: %d", irqn, err[nr]); \
		goto irq_error; \
	} else { \
		pdev->irq_mapping[irqn] = pci_irq_vector(pdev->pdev, irqn); \
		DEVLOG(dev->dev_id, TLKM_LF_IRQ, "interrupt line %d/%d assigned with return value %d", \
				irqn, pci_irq_vector(pdev->pdev, irqn), err[nr]); \
		INIT_WORK(&pdev->irq_work[nr], aws_ec2_tlkm_pcie_slot_irq_work_ ## nr); \
	}
	TLKM_AWS_EC2_SLOT_INTERRUPTS
#undef _INTR
	return 0;

irq_error:
#define _INTR(nr) \
	irqn = nr + pcie_cls.npirqs; \
	if (! err[nr]) { \
		free_irq(pdev->irq_mapping[irqn], pdev->pdev); \
		pdev->irq_mapping[irqn] = -1; \
	} else { \
		ret = err[nr]; \
	}
	TLKM_AWS_EC2_SLOT_INTERRUPTS
#undef _INTR
	return ret;
}

void aws_ec2_pcie_irqs_exit(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	int irqn;

#define _INTR(nr) \
	irqn = nr + pcie_cls.npirqs; \
	if (pdev->irq_mapping[irqn] != -1) { \
		DEVLOG(dev->dev_id, TLKM_LF_IRQ, "freeing interrupt %d with mappping %d", irqn, pdev->irq_mapping[irqn]); \
		free_irq(pdev->irq_mapping[irqn], pdev->pdev); \
		pdev->irq_mapping[irqn] = -1; \
	}
	TLKM_AWS_EC2_SLOT_INTERRUPTS
#undef _INTR

	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "interrupts deactivated");
}

// ******************************
// end aws ec2 interrupt handling
// ******************************

int pcie_irqs_request_platform_irq(struct tlkm_device *dev, int irq_no, irq_handler_t intr_handler, void *data)
{
	int err = 0;
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	BUG_ON(! pdev);
	if (irq_no >= dev->cls->npirqs) {
		DEVERR(dev->dev_id, "invalid platform interrupt number: %d (must be < %zd)", irq_no, dev->cls->npirqs);
		return -ENXIO;
	}

	BUG_ON(! pdev->pdev);
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "requesting platform irq #%d", irq_no);
	if ((err = request_irq(pci_irq_vector(pdev->pdev, irq_no),
			intr_handler,
			IRQF_EARLY_RESUME,
			TLKM_PCI_NAME,
			data))) {
		DEVERR(dev->dev_id, "could not request interrupt #%d: %d", irq_no, err);
		return err;
	}
	pdev->irq_mapping[irq_no] = pci_irq_vector(pdev->pdev, irq_no);
	pdev->irq_data[irq_no] = data;
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "created mapping from interrupt %d -> %d", irq_no, pdev->irq_mapping[irq_no]);
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "interrupt line %d/%d assigned with return value %d",
			irq_no, pci_irq_vector(pdev->pdev, irq_no), err);
	return err;
}

void pcie_irqs_release_platform_irq(struct tlkm_device *dev, int irq_no)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	if (irq_no >= dev->cls->npirqs) {
		DEVERR(dev->dev_id, "invalid platform interrupt number: %d (must be < %zd)", irq_no, pcie_cls.npirqs);
		return;
	}
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "freeing platform interrupt #%d with mapping %d", irq_no, pdev->irq_mapping[irq_no]);
	if (pdev->irq_mapping[irq_no] != -1) {
		free_irq(pdev->irq_mapping[irq_no], pdev->irq_data[irq_no]);
		pdev->irq_mapping[irq_no] = -1;
		pdev->irq_data[irq_no] = NULL;
	}
}
