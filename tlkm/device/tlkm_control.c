#include <linux/slab.h>
#include <linux/gfp.h>
#include <linux/fs.h>
#include "tlkm_logging.h"
#include "tlkm_control.h"
#include "tlkm_control_fops.h"
#include "tlkm_perfc.h"
#include "tlkm_device_ioctl.h"

static const struct file_operations _tlkm_control_fops = {
	.unlocked_ioctl = tlkm_device_ioctl,
	.read  		= tlkm_control_fops_read,
	.write 		= tlkm_control_fops_write,
};

static int init_miscdev(struct tlkm_control *pctl)
{
	char fn[16];
	snprintf(fn, 16, "tlkm_%03u", pctl->dev_id);
	LOG(TLKM_LF_CONTROL, "creating miscdevice %s for device #%03u", fn, pctl->dev_id);
	pctl->miscdev.minor = MISC_DYNAMIC_MINOR;
	pctl->miscdev.name  = kstrdup(fn, GFP_KERNEL);
	pctl->miscdev.fops  = &_tlkm_control_fops;
	return misc_register(&pctl->miscdev);
}

static void exit_miscdev(struct tlkm_control *pctl)
{
	misc_deregister(&pctl->miscdev);
	kfree(pctl->miscdev.name);
	pctl->miscdev.name = NULL;
	LOG(TLKM_LF_CONTROL, "destroyed miscdevice for device #%03u", pctl->dev_id);
}

ssize_t tlkm_control_signal_slot_interrupt(struct tlkm_control *pctl, const u32 s_id)
{
	mutex_lock(&pctl->out_mutex);
	while (pctl->outstanding > TLKM_CONTROL_BUFFER_SZ - 2) {
		WRN("buffer thrashing, throttling write ...");
		mutex_unlock(&pctl->out_mutex);
		wait_event_interruptible(pctl->write_q, pctl->outstanding <= (TLKM_CONTROL_BUFFER_SZ / 2));
		if (signal_pending(current)) return -ERESTARTSYS;
		mutex_lock(&pctl->out_mutex);
	}
	mutex_unlock(&pctl->out_mutex);
	LOG(TLKM_LF_CONTROL, "device #%03u: signaling slot #%u", pctl->dev_id, s_id);
	mutex_lock(&pctl->out_mutex);
	pctl->out_slots[pctl->out_w_idx] = s_id;
	pctl->out_w_idx = (pctl->out_w_idx + 1) % TLKM_CONTROL_BUFFER_SZ;
	++pctl->outstanding;
	tlkm_perfc_control_signaled_inc(pctl->dev_id);
#ifndef NDEBUG
	if (pctl->outstanding >= TLKM_CONTROL_BUFFER_SZ)
		WRN("buffer size exceeded! expect missing data!");
#endif
	mutex_unlock(&pctl->out_mutex);
	wake_up_interruptible(&pctl->read_q);
	return sizeof(u32);
}

int  tlkm_control_init(dev_id_t dev_id, struct tlkm_control **ppctl)
{
	int ret = 0;
	struct tlkm_control *p = (struct tlkm_control *)kzalloc(sizeof(*p), GFP_KERNEL);
	if (! p) {
		ERR("could not allocate struct tlkm_control");
		return -ENOMEM;
	}
	p->dev_id = dev_id;
	init_waitqueue_head(&p->read_q);
	init_waitqueue_head(&p->write_q);
	p->out_r_idx = 0;
	p->out_w_idx = 0;
	p->outstanding = 0;
	mutex_init(&p->out_mutex);
	if ((ret = init_miscdev(p))) {
		ERR("could not initialize control for device #%03u: %d", dev_id, ret);
		goto err_miscdev;
	}
	*ppctl = p;
	LOG(TLKM_LF_CONTROL, "initialized control for device #%03u", dev_id);
	return 0;

err_miscdev:
	kfree(p);
	return ret;
}

void tlkm_control_exit(struct tlkm_control *pctl)
{
	if (pctl) {
		dev_id_t dev_id = pctl->dev_id;
		exit_miscdev(pctl);
		kfree(pctl);
		LOG(TLKM_LF_CONTROL, "destroyed control for device #%03u", dev_id);
	}
}
