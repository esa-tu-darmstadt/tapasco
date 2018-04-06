#include <linux/dma-mapping.h>
#include "tlkm_logging.h"
#include "zynq_mmap.h"
#include "zynq_platform.h"

int zynq_mmap(struct tlkm_device_inst *dp, struct vm_area_struct *vm)
{
	ssize_t const sz = vm->vm_end - vm->vm_start;
	ulong const off = vm->vm_pgoff << PAGE_SHIFT;
	DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "received mmap");
	if (ISBETWEEN(off, ZYNQ_PLATFORM_GP0_BASE, ZYNQ_PLATFORM_GP0_HIGH)) {
		DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "mapping into GP0: 0x%08lx - 0x%08lx", vm->vm_start, vm->vm_end);
	} else if (ISBETWEEN(off, ZYNQ_PLATFORM_GP1_BASE, ZYNQ_PLATFORM_GP1_HIGH)) {
		DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "mapping into GP1: 0x%08lx - 0x%08lx", vm->vm_start, vm->vm_end);
	} else if (ISBETWEEN(off, ZYNQ_PLATFORM_STATUS_BASE, ZYNQ_PLATFORM_STATUS_HIGH)) {
		DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "mapping into ST: 0x%08lx - 0x%08lx", vm->vm_start, vm->vm_end);
	} else {
		DEVERR(dp->dev_id, "unrecognized offset: 0x%08lx", off);
		return -ENXIO;
	}

	DEVLOG(dp->dev_id, TLKM_LF_CONTROL,
			"mapping %zu bytes, from 0x%08lx-0x%08lx", sz, vm->vm_start, vm->vm_end);
	vm->vm_page_prot = pgprot_noncached(vm->vm_page_prot);
	if (io_remap_pfn_range(vm, vm->vm_start, off >> PAGE_SHIFT, sz, vm->vm_page_prot)) {
		DEVWRN(dp->dev_id, "io_remap_pfn_range failed!");
		return -EAGAIN;
	}
	DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "register space mapping successful");
	return 0;
}
