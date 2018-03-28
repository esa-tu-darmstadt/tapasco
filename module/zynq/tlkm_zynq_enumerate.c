#include <linux/of.h>
#include "tlkm_logging.h"
#include "tlkm_devices.h"
#include "tlkm_zynq_enumerate.h"

#define ZYNQ_NAME			"xlnx,zynq-7000"

static const struct of_device_id zynq_ids[] = {
	{ .compatible = "xlnx,zynq-7000", },
	{},
};

static tlkm_device_t zynq_dev = {
	.name = "xlnx,zynq-7000",
	.init = NULL,
	.exit = NULL,
};

ssize_t tlkm_zynq_enumerate(struct list_head *devs)
{
	LOG(TLKM_LF_DEVICE, "searching for Xilinx Zynq-7000 series devices ...");
	if (of_find_matching_node(NULL, zynq_ids)) {
		LOG(TLKM_LF_DEVICE, "found Xilinx Zynq-7000");
		list_add(&zynq_dev.device, devs);
		return 1;
	}
	LOG(TLKM_LF_DEVICE, "no Xilinx Zynq-7000 series device found");
	return 0;
}
