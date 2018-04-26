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

static const struct of_device_id zynq_ids[] = {
	{ .compatible = ZYNQ_NAME, },
	{},
};

static struct zynq_device _zynq_dev;		// there is at most one Zynq

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

	if ((ret = zynq_irq_init(&_zynq_dev))) {
		DEVERR(inst->dev_id, "could not initialize interrupts: %d", ret);
		goto err_irq;
	}

	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "zynq successfully initialized");
	return 0;

err_irq:
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
	inst->private_data = NULL;
	zynq_dmamgmt_exit();
	DEVLOG(_zynq_dev.parent->dev_id, TLKM_LF_DEVICE, "zynq device exited");
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
