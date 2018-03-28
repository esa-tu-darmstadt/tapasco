#include <linux/gfp.h>
#include <linux/slab.h>
#include "tlkm_logging.h"
#include "tlkm_devices.h"

static
int create_device_instance(struct tlkm_device *pdev, tlkm_access_t access)
{
	pdev->inst = kmalloc(sizeof(*(pdev->inst)), GFP_KERNEL);
	if (! pdev->inst) {
		ERR("could not allocate kernel memory for device instance");
		return -ENOMEM;
	}
	memset(pdev->inst, 0, sizeof(*(pdev->inst)));
	pdev->inst->dev_id 		= pdev->dev_id;
	pdev->inst->ref_cnt[access] 	= 1;
	pdev->inst->private_data 	= NULL;
	return pdev->init(pdev->inst);
}

static
void destroy_device_instance(struct tlkm_device *pdev)
{
	if (pdev->inst) {
		pdev->exit(pdev->inst);
		kfree(pdev->inst);
		pdev->inst = NULL;
	}
}

int tlkm_device_create(struct tlkm_device *pdev, tlkm_access_t access)
{
	int ret = 0;
#ifndef NDEBUG
	if (! pdev) {
		ERR("called with NULL device");
		return -ENXIO;
	}
#endif
	mutex_lock(&pdev->mtx);
	if (pdev->inst) {
		LOG(TLKM_LF_DEVICE, "instance for device #%03u already exists, "
				"checking permissions ...", pdev->dev_id);
		if (pdev->inst->ref_cnt[TLKM_ACCESS_EXCLUSIVE]) {
			if (access != TLKM_ACCESS_MONITOR) {
				ERR("cannot share exclusive instance for device #%03u",
						pdev->dev_id);
				ret = -EPERM;
			}
		}
		if (pdev->inst->ref_cnt[TLKM_ACCESS_SHARED]) {
			if (access == TLKM_ACCESS_EXCLUSIVE) {
				ERR("shared instance for device #%03u exists, "
						"cannot access exclusively",
						pdev->dev_id);
				ret = -EPERM;
			}
		}
		if (! ret) {
			LOG(TLKM_LF_DEVICE, "instance for device #%03u exists",
					pdev->dev_id);
			LOG(TLKM_LF_DEVICE, "ref_cnts: excl = %zu, shared = %zu, mon = %zu",
					pdev->inst->ref_cnt[TLKM_ACCESS_EXCLUSIVE],
					pdev->inst->ref_cnt[TLKM_ACCESS_SHARED],
					pdev->inst->ref_cnt[TLKM_ACCESS_MONITOR]);
			++(pdev->inst->ref_cnt[access]);
		}
	} else {
		LOG(TLKM_LF_DEVICE, "instance for device #%03u does not exist, "
				"creating ...", pdev->dev_id);
		ret = create_device_instance(pdev, access);
	}
	mutex_unlock(&pdev->mtx);
	return ret;
}

void tlkm_device_destroy(struct tlkm_device *pdev, tlkm_access_t access)
{
	tlkm_access_t a;
	mutex_lock(&pdev->mtx);
	if (pdev->inst) {
		size_t total_refs = 0;
		for (a = (tlkm_access_t)0; a < TLKM_ACCESS_TYPES; ++a) {
			total_refs += pdev->inst->ref_cnt[a];
		}
		if (total_refs > 1) {
			LOG(TLKM_LF_DEVICE, "ref_cnt of instance for device #%03u is %zu",
					pdev->dev_id, total_refs);
			--pdev->inst->ref_cnt[access];
		} else {
			LOG(TLKM_LF_DEVICE, "instance for device #%03u is no longer referenced",
					pdev->dev_id);
			destroy_device_instance(pdev);
		}
	} else {
		WRN("device #%03u has not yet been created or is already destroyed",
				pdev->dev_id);
	}
	mutex_unlock(&pdev->mtx);
}
