#include <linux/fs.h>
#include "tlkm_logging.h"
#include "tlkm_bus.h"
#include "tlkm_control.h"

static inline
struct tlkm_device *device_from_file(struct file *fp)
{
	struct miscdevice *m = (struct miscdevice *)fp->private_data;
	struct tlkm_control *c = (struct tlkm_control *)container_of(m, struct tlkm_control, miscdev);
	return tlkm_bus_get_device(c->dev_id);
}

int tlkm_device_mmap(struct file *fp, struct vm_area_struct *vm)
{
	struct tlkm_device *d = device_from_file(fp);
	tlkm_device_mmap_f mmap_f = d->mmap;
	if (! mmap_f) {
		DEVWRN(d->dev_id, "device has no mmap() implementation, register accesses are likely  slow!");
	}
	return mmap_f ? mmap_f(d->inst, vm) : -ENXIO;
}
