#include <linux/fs.h>
#include "tlkm_logging.h"
#include "zynq_device.h"

static struct zynq_dev {
	dev_id_t 	dev_id;
} _zynq_dev;

int  zynq_device_init(struct tlkm_device_inst *inst)
{
#ifndef NDEBUG
	if (! inst) {
		ERR("called with NULL device instance");
		return -EACCES;
	}
#endif /* NDEBUG */
	LOG(TLKM_LF_DEVICE, "initializing zynq device #%03u", inst->dev_id);
	inst->private_data = (void *)&_zynq_dev;
	_zynq_dev.dev_id = inst->dev_id;
	LOG(TLKM_LF_DEVICE, "zynq device #%03u successfully initialized",
			_zynq_dev.dev_id);
	return 0;
}

void zynq_device_exit(struct tlkm_device_inst *inst)
{
#ifndef NDEBUG
	if (! inst) {
		ERR("called with NULL device instance");
		return;
	}
#endif /* NDEBUG */
	inst->private_data = NULL;
	LOG(TLKM_LF_DEVICE, "zynq device #%03u exited", _zynq_dev.dev_id);
}
