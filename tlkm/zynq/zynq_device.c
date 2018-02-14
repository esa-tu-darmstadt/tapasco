#include <linux/of.h>
#include <linux/fs.h>
#include <linux/io.h>
#include "tlkm_logging.h"
#include "tlkm_types.h"
#include "tlkm_bus.h"
#include "zynq.h"
#include "zynq_device.h"
#include "zynq_irq.h"
#include "zynq_dmamgmt.h"
#include "zynq_platform.h"

static const struct of_device_id zynq_ids[] = {
	{ .compatible = ZYNQ_NAME, },
	{},
};

static struct zynq_device _zynq_dev;		// there is at most one Zynq

static int init_iomapping(void)
{
	int retval = 0;
	u32 magic_id = 0;
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for GP0",
			(void *)ZYNQ_PLATFORM_GP0_BASE,
			(void *)(ZYNQ_PLATFORM_GP0_BASE + ZYNQ_PLATFORM_GP0_SIZE - 1));
	_zynq_dev.gp_map[0] = ioremap_nocache(ZYNQ_PLATFORM_GP0_BASE, ZYNQ_PLATFORM_GP0_SIZE);
	if (! _zynq_dev.gp_map[0]) {
		DEVERR(_zynq_dev.dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)ZYNQ_PLATFORM_GP0_BASE,
				(void *)(ZYNQ_PLATFORM_GP0_BASE + ZYNQ_PLATFORM_GP0_SIZE - 1));
		retval = -ENOMEM;
		goto err_gp0;
	}

	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for GP1",
			(void *)ZYNQ_PLATFORM_GP1_BASE,
			(void *)(ZYNQ_PLATFORM_GP1_BASE + ZYNQ_PLATFORM_GP1_SIZE - 1));
	_zynq_dev.gp_map[1] = ioremap_nocache(ZYNQ_PLATFORM_GP1_BASE, ZYNQ_PLATFORM_GP1_SIZE);
	if (! _zynq_dev.gp_map[1]) {
		DEVERR(_zynq_dev.dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)ZYNQ_PLATFORM_GP1_BASE,
				(void *)(ZYNQ_PLATFORM_GP1_BASE + ZYNQ_PLATFORM_GP1_SIZE - 1));
		retval = -ENOMEM;
		goto err_gp1;
	}

	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%px-0x%px for ST",
			(void *)ZYNQ_PLATFORM_STATUS_BASE,
			(void *)(ZYNQ_PLATFORM_STATUS_BASE + ZYNQ_PLATFORM_STATUS_SIZE - 1));
	_zynq_dev.tapasco_status = ioremap_nocache(ZYNQ_PLATFORM_STATUS_BASE, ZYNQ_PLATFORM_STATUS_SIZE);
	if (! _zynq_dev.tapasco_status) {
		DEVERR(_zynq_dev.dev_id,
				"could not ioremap the AXI register space at 0x%px-0x%px",
				(void *)ZYNQ_PLATFORM_STATUS_BASE,
				(void *)(ZYNQ_PLATFORM_STATUS_BASE + ZYNQ_PLATFORM_STATUS_SIZE));
		retval = -ENOMEM;
		goto err_tapasco_status;
	}
	magic_id = ioread32(_zynq_dev.tapasco_status);
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE,  "magic_id = 0x%08lx", (ulong)magic_id);
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE,
			"I/O mapped all registers successfully: GP0 = 0x%px, GP1 = 0x%08lx, ST=0x%08lx",
			_zynq_dev.gp_map[0], (ulong)_zynq_dev.gp_map[1], (ulong)_zynq_dev.tapasco_status);
	return retval;

err_tapasco_status:
	iounmap(_zynq_dev.gp_map[1]);
err_gp1:
	iounmap(_zynq_dev.gp_map[0]);
err_gp0:
	return retval;
}

static void exit_iomapping(void)
{
	iounmap(_zynq_dev.tapasco_status);
	iounmap(_zynq_dev.gp_map[1]);
	iounmap(_zynq_dev.gp_map[0]);
	_zynq_dev.gp_map[0] = NULL;
	_zynq_dev.gp_map[1] = NULL;
	_zynq_dev.tapasco_status = NULL;
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "released all I/O maps");
}

int zynq_device_init(struct tlkm_device *inst, void *data)
{
	int ret = 0;
#ifndef NDEBUG
	if (! inst) {
		ERR("called with NULL device instance");
		return -EACCES;
	}
#endif /* NDEBUG */
	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "initializing zynq device");
	inst->private_data = &_zynq_dev;
	_zynq_dev.parent   = inst;

	if ((ret = zynq_dmamgmt_init())) {
		DEVERR(inst->dev_id, "could not initialize DMA management: %d", ret);
		goto err_dmamgmt;
	}

	if ((ret = init_iomapping())) {
		DEVERR(inst->dev_id, "could not initialize I/O-mapping: %d", ret);
		goto err_iomapping;
	}

	if ((ret = zynq_irq_init(&_zynq_dev))) {
		DEVERR(inst->dev_id, "could not initialize interrupts: %d", ret);
		goto err_irq;
	}

	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "zynq successfully initialized");
	return 0;

err_irq:
	exit_iomapping();
err_iomapping:
	zynq_dmamgmt_exit();
err_dmamgmt:
	return ret;
}

void zynq_device_exit(struct tlkm_device *inst)
{
#ifndef NDEBUG
	if (! inst) {
		ERR("called with NULL device instance");
		return;
	}
#endif /* NDEBUG */
	zynq_irq_exit(&_zynq_dev);
	exit_iomapping();
	inst->private_data = NULL;
	zynq_dmamgmt_exit();
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "zynq device exited");
}

int zynq_device_probe(struct tlkm_class *cls)
{
	struct tlkm_device *inst;
	LOG(TLKM_LF_DEVICE, "searching for Xilinx Zynq-7000 series devices ...");
	if (of_find_matching_node(NULL, zynq_ids)) {
		LOG(TLKM_LF_DEVICE, "found Xilinx Zynq-7000");
		inst = tlkm_bus_new_device(cls, 0, 0, NULL);
		if (! inst)
			return -EFAULT;
	} else {
		LOG(TLKM_LF_DEVICE, "no Xilinx Zynq-7000 series device found");
	}
	return 0;
}
