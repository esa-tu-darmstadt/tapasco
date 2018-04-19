#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/module.h>
#include "tlkm.h"
#include "tlkm_ioctl_cmds.h"
#include "tlkm_ioctl.h"
#include "tlkm_logging.h"

static struct {
	struct miscdevice	miscdev;
	int			is_setup;
} _tlkm;

static const struct file_operations _tlkm_fops = {
	.owner		= THIS_MODULE,
	.unlocked_ioctl	= tlkm_ioctl_ioctl,
};

int tlkm_init(void)
{
	LOG(TLKM_LF_MODULE, "initializing ioctl file " TLKM_IOCTL_FN " ...");
	_tlkm.miscdev.minor = MISC_DYNAMIC_MINOR;
	_tlkm.miscdev.name  = TLKM_IOCTL_FN;
	_tlkm.miscdev.fops  = &_tlkm_fops;
	_tlkm.is_setup	    = 1;
	return misc_register(&_tlkm.miscdev);
}

void tlkm_exit(void)
{
	if (_tlkm.is_setup)
		misc_deregister(&_tlkm.miscdev);
	LOG(TLKM_LF_MODULE, "removed ioctl file " TLKM_IOCTL_FN);
}
