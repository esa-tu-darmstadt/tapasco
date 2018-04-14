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
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)atomic_long_read(&work->data); \
	BUG_ON(! dev->ctrl); \
	tlkm_control_signal_slot_interrupt(dev->ctrl, nr); \
} \
\
irqreturn_t tlkm_pcie_slot_irq_ ## nr(int irq, void *dev_id) 		\
{ 									\
	struct pci_dev *pdev = (struct pci_dev *)dev_id; \
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *) dev_get_drvdata(&pdev->dev); \
	BUG_ON(! dev); \
	schedule_work(&dev->irq_work[nr]); \
	return IRQ_HANDLED; \
}

TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR

int pcie_irqs_init(struct pci_dev *pdev)
{
#define _INTR(nr) + 1
	size_t const n = 0 TLKM_PCIE_SLOT_INTERRUPTS;
#undef _INTR
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	int ret = 0, err[n];
	BUG_ON(! dev);
	LOG(TLKM_LF_PCIE, "registering %zu interrupts ...", n);
#define _INTR(nr) \
	if ((err[nr] = request_irq(pci_irq_vector(pdev, nr), \
			tlkm_pcie_slot_irq_ ## nr, \
			IRQF_EARLY_RESUME, \
			TLKM_PCI_NAME, \
			pdev))) { \
		ERR("could not request interrupt %d: %d", nr, err[nr]); \
		goto irq_error; \
	} else { \
		dev->irq_mapping[nr] = pci_irq_vector(pdev, nr); \
		LOG(TLKM_LF_PCIE, "created mapping from interrupt %d -> %d", nr, dev->irq_mapping[nr]); \
		LOG(TLKM_LF_PCIE, "interrupt line %d/%d assigned with return value %d", \
				nr, pci_irq_vector(pdev, nr), err[nr]); \
		INIT_WORK(&dev->irq_work[nr], tlkm_pcie_slot_irq_work_ ## nr); \
		atomic_long_set(&dev->irq_work[nr].data, (long)dev); \
	}
	TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR
	return 0;

irq_error:
#define _INTR(nr) \
	if (! err[nr]) { \
		free_irq(dev->irq_mapping[nr], pdev); \
		dev->irq_mapping[nr] = -1; \
	} else { \
		ret = err[nr]; \
	}
	TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR
	return ret;
}

void pcie_irqs_deinit(struct pci_dev *pdev)
{
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	BUG_ON(! dev);
#define _INTR(nr) \
	if (dev->irq_mapping[nr] != -1) { \
		LOG(TLKM_LF_PCIE, "freeing intterupt %d with mappping %d", nr, dev->irq_mapping[nr]); \
		free_irq(dev->irq_mapping[nr], pdev); \
		dev->irq_mapping[nr] = -1; \
	}
	TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	pci_disable_msix(pdev);
#else
	pci_free_irq_vectors(pdev);
#endif
}
