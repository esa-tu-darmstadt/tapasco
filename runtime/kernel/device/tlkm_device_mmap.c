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
	struct tlkm_device *dp = device_from_file(fp);
	ssize_t const sz = vm->vm_end - vm->vm_start;
	ulong const off = vm->vm_pgoff << PAGE_SHIFT;
	ulong kptr = addr2map_off(dp, off);
	DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "received mmap: offset = 0x%08lx", off);
	if (kptr == -1) {
		DEVERR(dp->dev_id, "invalid address: 0x%08lx", off);
		return -ENXIO;
	}

	DEVLOG(dp->dev_id, TLKM_LF_CONTROL,
			"mapping %zu bytes from physical address 0x%lx to user space 0x%lx-0x%lx", sz,
			dp->base_offset + kptr, vm->vm_start, vm->vm_end);
	vm->vm_page_prot = pgprot_noncached(vm->vm_page_prot);
	if (io_remap_pfn_range(vm, vm->vm_start, (dp->base_offset + kptr) >> PAGE_SHIFT, sz, vm->vm_page_prot)) {
		DEVWRN(dp->dev_id, "io_remap_pfn_range failed!");
		return -EAGAIN;
	}
	DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "register space mapping successful");
	return 0;
}
