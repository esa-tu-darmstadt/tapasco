#ifndef TLKM_CONTROL_H__
#define TLKM_CONTROL_H__

#include <linux/types.h>
#include <linux/mutex.h>
#include <linux/sched.h>
#include <linux/miscdevice.h>
#include "tlkm_types.h"

#define TLKM_CONTROL_BUFFER_SZ					1024U

struct tlkm_control {
	dev_id_t 		dev_id;
	struct miscdevice 	miscdev;
	wait_queue_head_t	read_q;
	wait_queue_head_t	write_q;
	u32			out_slots[TLKM_CONTROL_BUFFER_SZ];
	u32			out_r_idx;
	u32			out_w_idx;
	struct mutex		out_mutex;
	u32			outstanding;
};

ssize_t tlkm_control_signal_slot_interrupt(struct tlkm_control *pctl, const u32 s_id);
int  tlkm_control_init(dev_id_t dev_id, struct tlkm_control **ppctl);
void tlkm_control_exit(struct tlkm_control *pctl);

#endif /* TLKM_CONTROL_H__ */
