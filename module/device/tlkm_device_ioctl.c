#include <linux/uaccess.h>
#include <linux/string.h>
#include <linux/miscdevice.h>
#include "tlkm_logging.h"
#include "tlkm_device_ioctl_cmds.h"
#include "tlkm_bus.h"
#include "tlkm_control.h"

struct tlkm_control *control_from_file(struct file *fp)
{
	struct miscdevice *m = (struct miscdevice *)fp->private_data;
	return (struct tlkm_control *)container_of(m, struct tlkm_control, miscdev);
}

long tlkm_device_ioctl_INFO(struct file *fp, unsigned int ioctl,
		struct tlkm_device_info __user *info)
{
	struct tlkm_device_info kinfo;
	struct tlkm_device *kdev;
	struct tlkm_control *c = control_from_file(fp);
	LOG(TLKM_LF_CONTROL, "device #%03u: received info ioctl", c->dev_id);
	if (! c) {
		ERR("received invalid file pointer");
		return -EFAULT;
	}
	kdev = tlkm_bus_get_device(c->dev_id);
	if (! kdev) {
		ERR("bus has become invalid");
		return -EFAULT;
	}
	kinfo.dev_id = c->dev_id;
	kinfo.vendor_id = kdev->vendor_id;
	kinfo.product_id = kdev->product_id;
	strncpy(kinfo.name, kdev->name, TLKM_DEVNAME_SZ);
	if (copy_to_user((void __user *)info, &kinfo, sizeof(kinfo))) {
		ERR("could not copy all bytes to user space");
		return -EAGAIN;
	}
	return 0;
}

long tlkm_device_ioctl(struct file *fp, unsigned int ioctl, unsigned long data)
{
#define _TLKM_DEV_IOCTL(name, id,  dt) \
	if (ioctl == TLKM_DEV_IOCTL_ ## name) { \
		return tlkm_device_ioctl_ ## name(fp, ioctl, (dt __user *)data); \
	}
	TLKM_DEV_IOCTL_CMDS
#undef _TLKM_DEV_IOCTL
	ERR("illegal ioctl received: 0x%08x", ioctl);
	return -EIO;
}
