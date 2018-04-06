#include <linux/fs.h>
#include <linux/io.h>
#include "tlkm_logging.h"
#include "tlkm_types.h"
#include "zynq_device.h"
#include "zynq_irq.h"
#include "zynq_platform.h"

static struct zynq_device _zynq_dev;

static int init_iomapping(void)
{
	int retval = 0;
	u32 magic_id = 0;
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%08llx-0x%08llx for GP0",
			(u64)ZYNQ_PLATFORM_GP0_BASE,
			(u64)(ZYNQ_PLATFORM_GP0_BASE + ZYNQ_PLATFORM_GP0_SIZE - 1));
	_zynq_dev.gp_map[0] = ioremap_nocache(ZYNQ_PLATFORM_GP0_BASE, ZYNQ_PLATFORM_GP0_SIZE);
	if (!_zynq_dev.gp_map[0] || IS_ERR(_zynq_dev.gp_map[0])) {
		DEVERR(_zynq_dev.dev_id,
				"could not ioremap the AXI register space at 0x%08llx-0x%08llx",
				(u64)ZYNQ_PLATFORM_GP0_BASE,
				(u64)(ZYNQ_PLATFORM_GP0_BASE + ZYNQ_PLATFORM_GP0_SIZE - 1));
		retval = PTR_ERR(_zynq_dev.gp_map[0]);
		goto err_gp0;
	}

	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%08llx-0x%08llx for GP1",
			(u64)ZYNQ_PLATFORM_GP1_BASE,
			(u64)(ZYNQ_PLATFORM_GP1_BASE + ZYNQ_PLATFORM_GP1_SIZE - 1));
	_zynq_dev.gp_map[1] = ioremap_nocache(ZYNQ_PLATFORM_GP1_BASE, ZYNQ_PLATFORM_GP1_SIZE);
	if (!_zynq_dev.gp_map[1] || IS_ERR(_zynq_dev.gp_map[1])) {
		DEVERR(_zynq_dev.dev_id,
				"could not ioremap the AXI register space at 0x%08llx-0x%08llx",
				(u64)ZYNQ_PLATFORM_GP1_BASE,
				(u64)(ZYNQ_PLATFORM_GP1_BASE + ZYNQ_PLATFORM_GP1_SIZE - 1));
		retval = PTR_ERR(_zynq_dev.gp_map[1]);
		goto err_gp1;
	}

	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "I/O mapping 0x%08llx-0x%08llx for ST",
			(u64)ZYNQ_PLATFORM_STATUS_BASE,
			(u64)(ZYNQ_PLATFORM_STATUS_BASE + ZYNQ_PLATFORM_STATUS_SIZE - 1));
	_zynq_dev.tapasco_status = ioremap_nocache(ZYNQ_PLATFORM_STATUS_BASE, ZYNQ_PLATFORM_STATUS_SIZE);
	if (!_zynq_dev.tapasco_status || IS_ERR(_zynq_dev.tapasco_status)) {
		DEVERR(_zynq_dev.dev_id,
				"could not ioremap the AXI register space at 0x%08llx-0x%08llx",
				(u64)ZYNQ_PLATFORM_STATUS_BASE,
				(u64)(ZYNQ_PLATFORM_STATUS_BASE + ZYNQ_PLATFORM_STATUS_SIZE));
		retval = PTR_ERR(_zynq_dev.tapasco_status);
		goto err_tapasco_status;
	}
	magic_id = ioread32(_zynq_dev.tapasco_status);
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE,  "magic_id = 0x%08lx", (ulong)magic_id);
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE,
			"I/O mapped all registers successfully: GP0 = 0x%08lx, GP1 = 0x%08lx, ST=0x%08lx",
			(ulong)_zynq_dev.gp_map[0], (ulong)_zynq_dev.gp_map[1], (ulong)_zynq_dev.tapasco_status);
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

int zynq_device_init(struct tlkm_device_inst *inst)
{
	int ret = 0;
#ifndef NDEBUG
	if (! inst) {
		ERR("called with NULL device instance");
		return -EACCES;
	}
#endif /* NDEBUG */
	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "initializing zynq device");
	inst->private_data = (void *)&_zynq_dev;
	_zynq_dev.dev_id = inst->dev_id;

	if ((ret = init_iomapping())) {
		DEVERR(inst->dev_id, "could not initialize I/O-mapping: %d", ret);
		goto err_iomapping;
	}

	if ((ret = zynq_irq_init(&_zynq_dev, inst->ctrl))) {
		DEVERR(inst->dev_id, "could not initialize interrupts: %d", ret);
		goto err_irq;
	}

	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "zynq successfully initialized");
	return 0;

err_irq:
	exit_iomapping();
err_iomapping:
	return ret;
}

void zynq_device_exit(struct tlkm_device_inst *inst)
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
	DEVLOG(_zynq_dev.dev_id, TLKM_LF_DEVICE, "zynq device exited");
}
