#include <linux/of.h>
#include "tlkm_logging.h"

#define	ZYNQ_7000_ID				"xilinx,zynq-7000"

static const struct of_device_id zynq_id[] = {
	{ .compatible = ZYNQ_7000_ID, },
	{ /* sentinel */ },
};

int is_zynq_machine(void)
{
	if (! of_find_matching_node(NULL, zynq_id)) {
		LOG(TLKM_LF_DEVICE, "no zynq-7000 compatible devicetree node found");
		return 0;
	}
	return 1;
}
