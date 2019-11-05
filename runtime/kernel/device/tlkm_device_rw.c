#include <linux/uaccess.h>
#include <linux/version.h>
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 11, 0)
#include <linux/sched.h>
#else
#include <linux/sched/signal.h>
#endif
#include "tlkm_device_rw.h"
#include "tlkm_control.h"
#include "tlkm_perfc.h"
#include "tlkm_logging.h"

#define TLKM_CONTROL_MAX_READS 128

inline static struct tlkm_control *control_from_file(struct file *fp)
{
	struct miscdevice *m = (struct miscdevice *)fp->private_data;
	return container_of(m, struct tlkm_control, miscdev);
}

ssize_t tlkm_device_read(struct file *fp, char __user *usr, size_t sz,
			 loff_t *off)
{
	ssize_t out = 0;
	u32 out_val[TLKM_CONTROL_MAX_READS];
	size_t out_sz;
	struct tlkm_control *pctl = control_from_file(fp);
	if (!pctl) {
		DEVERR(pctl->dev_id, "received invalid file pointer");
		return -EFAULT;
	}
	do {
		mutex_lock(&pctl->out_mutex);
		out_sz = pctl->out_w_idx >= pctl->out_r_idx ?
				 pctl->out_w_idx - pctl->out_r_idx :
				 TLKM_CONTROL_BUFFER_SZ - pctl->out_r_idx;
		if (out_sz * sizeof(*(pctl->out_slots)) > sz) {
			out_sz = sz / sizeof(*(pctl->out_slots));
			tlkm_perfc_limited_by_read_sz_inc(pctl->dev_id);
		}
		if (out_sz > TLKM_CONTROL_MAX_READS) {
			out_sz = TLKM_CONTROL_MAX_READS;
			tlkm_perfc_limited_by_outbuf_sz_inc(pctl->dev_id);
		}
		out = pctl->out_w_idx != pctl->out_r_idx;
		if (out) {
			ssize_t i, j;
			if (pctl->out_w_idx < pctl->out_r_idx)
				tlkm_perfc_indices_reversed_inc(pctl->dev_id);
			else
				tlkm_perfc_indices_in_order_inc(pctl->dev_id);
			for (i = 0, j = pctl->out_r_idx; i < out_sz; ++i, ++j) {
				out_val[i] = pctl->out_slots[j];
			}
			pctl->out_r_idx = (pctl->out_r_idx + out_sz) %
					  TLKM_CONTROL_BUFFER_SZ;
			pctl->outstanding -= out_sz;
			tlkm_perfc_signals_read_add(pctl->dev_id, out_sz);
			tlkm_perfc_outstanding_set(pctl->dev_id,
						   pctl->outstanding);
		}
		mutex_unlock(&pctl->out_mutex);
		if (!out) {
			DEVLOG(pctl->dev_id, TLKM_LF_CONTROL,
			       "waiting on data ...");
			wait_event_interruptible(pctl->read_q,
						 pctl->out_w_idx !=
							 pctl->out_r_idx);
			if (signal_pending(current))
				return -ERESTARTSYS;
		} else {
			DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "read %zd bytes",
			       out_sz * sizeof(u32));
			wake_up_interruptible(&pctl->write_q);
		}
	} while (!out);
	out = copy_to_user(usr, out_val, out_sz * sizeof(*(pctl->out_slots)));
	if (out)
		return -EFAULT;
	return out_sz * sizeof(*(pctl->out_slots));
}

ssize_t tlkm_device_write(struct file *fp, const char __user *usr, size_t sz,
			  loff_t *off)
{
	u32 in_val = 0;
	ssize_t in;
	struct tlkm_control *pctl = control_from_file(fp);
	if (!pctl) {
		DEVERR(pctl->dev_id, "received invalid file pointer");
		return -EFAULT;
	}
	in = copy_from_user(&in_val, usr, sizeof(in_val));
	tlkm_perfc_signals_written_inc(pctl->dev_id);
	DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "received job %u as write",
	       in_val);
	if (in)
		return -EFAULT;
	return tlkm_control_signal_slot_interrupt(pctl, in_val);
}
