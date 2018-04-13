#include <linux/uaccess.h>
#include <linux/sched/signal.h>
#include "tlkm_device_rw.h"
#include "tlkm_control.h"
#include "tlkm_perfc.h"
#include "tlkm_logging.h"

inline static struct tlkm_control *control_from_file(struct file *fp)
{
	struct miscdevice *m = (struct miscdevice *)fp->private_data;
	return container_of(m, struct tlkm_control, miscdev);
}

ssize_t tlkm_device_read(struct file *fp, char __user *usr, size_t sz, loff_t *off)
{
	ssize_t out = 0;
	u32 out_val = 0;
	struct tlkm_control *pctl = control_from_file(fp);
	if (! pctl) {
		DEVERR(pctl->dev_id, "received invalid file pointer");
		return -EFAULT;
	}
	do {
		mutex_lock(&pctl->out_mutex);
		out = pctl->out_w_idx != pctl->out_r_idx;
		if (out) {
			out_val = pctl->out_slots[pctl->out_r_idx];
			pctl->out_r_idx = (pctl->out_r_idx + 1) % TLKM_CONTROL_BUFFER_SZ;
			--pctl->outstanding;
			tlkm_perfc_signals_read_inc(pctl->dev_id);
		}
		mutex_unlock(&pctl->out_mutex);
		if (! out) {
			DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "waiting on data ...");
			wait_event_interruptible(pctl->read_q, pctl->out_w_idx != pctl->out_r_idx);
			if (signal_pending(current)) return -ERESTARTSYS;
		} else {
			DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "read %zd bytes, out_val = %u", sz, out_val);
			wake_up_interruptible(&pctl->write_q);
		}
	} while (! out);
	out = copy_to_user(usr, &out_val, sizeof(out_val));
	if (out) return -EFAULT;
	return sizeof(out_val);
}

ssize_t tlkm_device_write(struct file *fp, const char __user *usr, size_t sz, loff_t *off)
{
	u32 in_val = 0;
	ssize_t in;
	struct tlkm_control *pctl = control_from_file(fp);
	if (! pctl) {
		DEVERR(pctl->dev_id, "received invalid file pointer");
		return -EFAULT;
	}
	in = copy_from_user(&in_val, usr, sizeof(in_val));
	tlkm_perfc_signals_written_inc(pctl->dev_id);
	DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "received job %u as write", in_val);
	if (in) return -EFAULT;
	return tlkm_control_signal_slot_interrupt(pctl, in_val);
}
