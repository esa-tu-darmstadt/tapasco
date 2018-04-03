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
	_zynq_dev.gp_map[0] = ioremap_nocache(ZYNQ_PLATFORM_GP0_BASE, ZYNQ_PLATFORM_GP0_SIZE);
	if (IS_ERR(_zynq_dev.gp_map[0])) {
		ERR("could not ioremap the AXI register space at 0x%08lx-0x%08lx",
				ZYNQ_PLATFORM_GP0_BASE,
				ZYNQ_PLATFORM_GP0_BASE + ZYNQ_PLATFORM_GP0_SIZE - 1);
		retval = PTR_ERR(_zynq_dev.gp_map[0]);
		goto err_gp0;
	}

	_zynq_dev.gp_map[1] = ioremap_nocache(ZYNQ_PLATFORM_GP1_BASE, ZYNQ_PLATFORM_GP1_SIZE);
	if (IS_ERR(_zynq_dev.gp_map[1])) {
		ERR("could not ioremap the AXI register space at 0x%08lx-0x%08lx",
				ZYNQ_PLATFORM_GP1_BASE,
				ZYNQ_PLATFORM_GP1_BASE + ZYNQ_PLATFORM_GP1_SIZE - 1);
		retval = PTR_ERR(_zynq_dev.gp_map[1]);
		goto err_gp1;
	}

	_zynq_dev.tapasco_status = ioremap_nocache(ZYNQ_PLATFORM_STATUS_BASE, ZYNQ_PLATFORM_STATUS_SIZE);
	if (IS_ERR(_zynq_dev.tapasco_status)) {
		ERR("could not ioremap the AXI register space at 0x%08lx-0x%08lx",
				ZYNQ_PLATFORM_STATUS_BASE,
				ZYNQ_PLATFORM_STATUS_BASE + ZYNQ_PLATFORM_STATUS_SIZE);
		retval = PTR_ERR(_zynq_dev.tapasco_status);
		goto err_tapasco_status;
	}
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
	LOG(TLKM_LF_DEVICE, "initializing zynq device #%03u", inst->dev_id);
	inst->private_data = (void *)&_zynq_dev;
	_zynq_dev.dev_id = inst->dev_id;

	if ((ret = init_iomapping())) {
		ERR("could not initialize io-mapping: %d", ret);
		goto err_iomapping;
	}

	if ((ret = zynq_irq_init(&_zynq_dev, inst->ctrl))) {
		ERR("could not initialize interrupts: %d", ret);
		goto err_irq;
	}

	LOG(TLKM_LF_DEVICE, "zynq device #%03u successfully initialized",
			_zynq_dev.dev_id);
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
	inst->private_data = NULL;
	LOG(TLKM_LF_DEVICE, "zynq device #%03u exited", _zynq_dev.dev_id);
}
