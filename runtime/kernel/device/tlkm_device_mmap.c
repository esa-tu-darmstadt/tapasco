/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo 
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
#include <linux/fs.h>
#include "tlkm_logging.h"
#include "tlkm_bus.h"
#include "tlkm_control.h"

static inline struct tlkm_device *device_from_file(struct file *fp)
{
	struct miscdevice *m = (struct miscdevice *)fp->private_data;
	struct tlkm_control *c = (struct tlkm_control *)container_of(
		m, struct tlkm_control, miscdev);
	return tlkm_bus_get_device(c->dev_id);
}

int tlkm_device_mmap(struct file *fp, struct vm_area_struct *vm)
{
	struct tlkm_device *dp = device_from_file(fp);
	ssize_t const sz = vm->vm_end - vm->vm_start;
	ulong const off = vm->vm_pgoff << PAGE_SHIFT;
	void *kptr = addr2map_off(dp, off);
	LOG(TLKM_LF_DEVICE, "calling mmap on device.");
	DEVLOG(dp->dev_id, TLKM_LF_CONTROL, "received mmap: offset = 0x%08lx",
	       off);
	
	if (strncmp(dp->name, "sim", 3) != 0) {
		if (kptr == 0) {
			DEVERR(dp->dev_id, "invalid address: 0x%08lx", off);
			return -ENXIO;
		}

		DEVLOG(dp->dev_id, TLKM_LF_CONTROL,
		       "mapping %zu bytes from physical address 0x%p to user space 0x%lx-0x%lx",
	  		sz, kptr, vm->vm_start, vm->vm_end);
		if ((off >> PAGE_SHIFT) < 4) {
			vm->vm_page_prot = pgprot_noncached(vm->vm_page_prot);
		}

		if (remap_pfn_range(vm, vm->vm_start, (size_t)kptr >> PAGE_SHIFT, sz,
				    vm->vm_page_prot)) {
			DEVWRN(dp->dev_id, "remap_pfn_range failed!");
			return -EAGAIN;
		}
	}
	DEVLOG(dp->dev_id, TLKM_LF_CONTROL,
	       "register space mapping successful");
	return 0;
}
