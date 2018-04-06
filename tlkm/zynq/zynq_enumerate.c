#include <linux/of.h>
#include <linux/mutex.h>
#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_bus.h"
#include "zynq_enumerate.h"
#include "zynq_device.h"
#include "zynq_platform.h"
#include "zynq_ioctl.h"
#include "zynq_mmap.h"

static const struct of_device_id zynq_ids[] = {
	{ .compatible = ZYNQ_NAME, },
	{},
};

static tlkm_device_t zynq_dev = {
	.device = LIST_HEAD_INIT(zynq_dev.device),
	.name   = ZYNQ_NAME,
	.init   = zynq_device_init,
	.exit   = zynq_device_exit,
	.ioctl  = zynq_ioctl,
	.mmap   = zynq_mmap,
};

ssize_t zynq_enumerate()
{
	LOG(TLKM_LF_DEVICE, "searching for Xilinx Zynq-7000 series devices ...");
	if (of_find_matching_node(NULL, zynq_ids)) {
		LOG(TLKM_LF_DEVICE, "found Xilinx Zynq-7000");
		mutex_init(&zynq_dev.mtx);
		tlkm_bus_add_device(&zynq_dev);
		return 1;
	}
	LOG(TLKM_LF_DEVICE, "no Xilinx Zynq-7000 series device found");
	return 0;
}
