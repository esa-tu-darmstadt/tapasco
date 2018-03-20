//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 *  @file	tapasco_pemgmt.c
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <tapasco_pemgmt.h>
#include <tapasco_device.h>
#include <tapasco_errors.h>
#include <tapasco_regs.h>
#include <tapasco_logging.h>
#include <tapasco_global.h>
#include <tapasco_jobs.h>
#include <tapasco_delayed_transfers.h>
#include <platform.h>
#include <platform_context.h>

/** State of PEs, e.g., busy or idle. */
typedef enum {
	TAPASCO_PE_STATE_IDLE 					= 1,
	TAPASCO_PE_STATE_READY,
	TAPASCO_PE_STATE_BUSY,
	TAPASCO_PE_STATE_DONE
} tapasco_pe_state_t;

/** Represents a processing element on the device. */
struct tapasco_pe {
	tapasco_kernel_id_t id;
	tapasco_slot_id_t slot_id;
	tapasco_pe_state_t state;
};
typedef struct tapasco_pe tapasco_pe_t;

static
tapasco_pe_t *tapasco_pemgmt_create(tapasco_kernel_id_t const k_id,
		tapasco_slot_id_t const slot_id)
{
	tapasco_pe_t *f = (tapasco_pe_t *)malloc(sizeof(tapasco_pe_t));
	f->id = k_id;
	f->slot_id = slot_id;
	f->state = TAPASCO_PE_STATE_IDLE;
	return f;
}

static inline
void tapasco_pemgmt_destroy(tapasco_pe_t *f)
{
	free(f);
}

/******************************************************************************/

struct tapasco_pemgmt {
	tapasco_pe_t *pe[TAPASCO_NUM_SLOTS];
};

static
void setup_pes_from_status(platform_ctx_t *ctx, tapasco_pemgmt_t *p)
{
	platform_info_t info;
	platform_res_t r = platform_info(ctx, &info);
	if (r != PLATFORM_SUCCESS) {
		ERR("could not get platform info: %s (%d)",
				platform_strerror(r), r);
		return;
	}
	for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i) {
		platform_kernel_id_t const k_id = info.composition.kernel[i];
		p->pe[i] = k_id ? tapasco_pemgmt_create(k_id, i) : NULL;
	}
}

tapasco_res_t tapasco_pemgmt_init(const tapasco_dev_ctx_t *dev_ctx,
		tapasco_pemgmt_t **pemgmt)
{
	tapasco_res_t res = TAPASCO_SUCCESS;
	*pemgmt = (tapasco_pemgmt_t *)malloc(sizeof(tapasco_pemgmt_t));
	if (! pemgmt) return TAPASCO_ERR_OUT_OF_MEMORY;
	memset(*pemgmt, 0, sizeof(**pemgmt));
	setup_pes_from_status(tapasco_device_platform(dev_ctx), *pemgmt);
	return res;
}

void tapasco_pemgmt_deinit(tapasco_pemgmt_t *pemgmt)
{
	for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i)
		tapasco_pemgmt_destroy(pemgmt->pe[i]);
	free(pemgmt);
}

void tapasco_pemgmt_setup_system(tapasco_dev_ctx_t *dev_ctx,
		tapasco_pemgmt_t *ctx)
{
	assert (ctx);
	uint32_t d = 1;
	tapasco_slot_id_t slot_id = 0;
	platform_ctx_t *pctx = tapasco_device_platform(dev_ctx);
	tapasco_pe_t **pemgmt = ctx->pe;
	while (slot_id < TAPASCO_NUM_SLOTS) {
		if (*pemgmt) {
			tapasco_handle_t const ier = tapasco_regs_named_register(
				dev_ctx, slot_id, TAPASCO_REG_IER);
			tapasco_handle_t const gier = tapasco_regs_named_register(
				dev_ctx, slot_id, TAPASCO_REG_GIER);
			tapasco_handle_t const iar = tapasco_regs_named_register(
				dev_ctx, slot_id, TAPASCO_REG_IAR);
			// enable IP interrupts
			LOG(LALL_PEMGMT, "writing GIER at 0x%08lx",
					(unsigned long)gier);
			platform_write_ctl(pctx, gier, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);		// GIER
			// enable ap_done interrupt generation
			LOG(LALL_PEMGMT, "writing IER at 0x%08lx",
					(unsigned long)ier);
			platform_write_ctl(pctx, ier, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE); 		// IPIER
			// ack all existing interrupts
			LOG(LALL_PEMGMT, "writing IAR at 0x%08lx",
					(unsigned long)iar);
			platform_read_ctl(pctx, iar, sizeof(d), &d, 
				PLATFORM_CTL_FLAGS_NONE);               // IAR
			platform_write_ctl(pctx, iar, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);
			d = 1;
		}
		++pemgmt;
		++slot_id;
	}

}

inline static
int reserve_pe(tapasco_pe_t *pe, tapasco_kernel_id_t const k_id)
{
	assert(pe != NULL);
	return pe->id == k_id && __sync_bool_compare_and_swap(&pe->state,
			TAPASCO_PE_STATE_IDLE, TAPASCO_PE_STATE_BUSY);
}

tapasco_slot_id_t tapasco_pemgmt_acquire(tapasco_pemgmt_t *ctx,
		tapasco_kernel_id_t const k_id)
{
	tapasco_pe_t **pemgmt = ctx->pe;
	int len = TAPASCO_NUM_SLOTS;
	while (len && *pemgmt && ! reserve_pe(*pemgmt, k_id) && (*pemgmt)->id) {
		--len;
		++pemgmt;
	}
	LOG(LALL_PEMGMT, "k_id = %d, slotid = %d",
			k_id, len > 0 && pemgmt &&
			*pemgmt ? (*pemgmt)->slot_id : -1);
	return len > 0 && *pemgmt ? (*pemgmt)->slot_id : -1;
}

inline
void tapasco_pemgmt_release(tapasco_pemgmt_t *ctx, tapasco_slot_id_t const s_id)
{
	assert(ctx);
	assert(ctx->pe[s_id]);
	LOG(LALL_PEMGMT, "slotid = %d", s_id);
	ctx->pe[s_id]->state = TAPASCO_PE_STATE_IDLE;
}

inline
size_t tapasco_pemgmt_count(tapasco_pemgmt_t const *ctx,
		tapasco_kernel_id_t const k_id)
{
	size_t ret = 0;
	for (tapasco_slot_id_t i = 0; i < TAPASCO_NUM_SLOTS; ++i)
		ret += ctx->pe[i] ? ctx->pe[i]->id == k_id : 0;
	return ret;
}

size_t tapasco_device_kernel_pe_count(tapasco_dev_ctx_t *dev_ctx,
		tapasco_kernel_id_t const k_id)
{
	return tapasco_pemgmt_count(tapasco_device_pemgmt(dev_ctx), k_id);

}

tapasco_res_t tapasco_pemgmt_start(tapasco_dev_ctx_t *dev_ctx,
		tapasco_slot_id_t const slot_id)
{
	uint32_t const start_cmd = 1;
	platform_ctx_t *pctx = tapasco_device_platform(dev_ctx);
	tapasco_handle_t ctl = tapasco_regs_named_register(dev_ctx, slot_id, TAPASCO_REG_CTRL);

	if (platform_write_ctl(pctx,
			ctl,
			sizeof(start_cmd),
			&start_cmd,
			PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_ERR_PLATFORM_FAILURE;

	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_pemgmt_prepare_slot(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const j_id,
		tapasco_slot_id_t const slot_id)
{
	tapasco_jobs_t *jobs     = tapasco_device_jobs(dev_ctx);
	platform_ctx_t *pctx = tapasco_device_platform(dev_ctx);
	size_t const num_args    = tapasco_jobs_arg_count(jobs, j_id);

	for (size_t a = 0; a < num_args; ++a) {
		tapasco_res_t r       = TAPASCO_SUCCESS;
		tapasco_handle_t h    = tapasco_regs_arg_register(dev_ctx, slot_id, a);
		tapasco_transfer_t *t = tapasco_jobs_get_arg_transfer(jobs, j_id, a);

		if (t->len > 0) {
			LOG(LALL_PEMGMT, "job %lu: transferring %zd byte arg #%zd",
					(unsigned long)j_id, t->len, a);
			r = tapasco_transfer_to(dev_ctx, j_id, t, slot_id);
			if (r != TAPASCO_SUCCESS) { return r; }
			LOG(LALL_PEMGMT, "job %lu: writing handle to arg #%zd (0x%08x)",
					(unsigned long)j_id, a, t->handle);
			if (platform_write_ctl(pctx, h, sizeof(t->handle),
					&t->handle, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
				return TAPASCO_ERR_PLATFORM_FAILURE;
		} else {
			tapasco_res_t r = tapasco_write_arg(dev_ctx, jobs, j_id, h, a);
			if (r != TAPASCO_SUCCESS) { return r; }
		}
	}
	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_pemgmt_finish_job(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const j_id)
{
	uint32_t ack_cmd = 1;
	uint64_t ret = 0;
	tapasco_jobs_t *jobs = tapasco_device_jobs(dev_ctx);
	platform_ctx_t *pctx = tapasco_device_platform(dev_ctx);
	tapasco_pemgmt_t *pemgmt = tapasco_device_pemgmt(dev_ctx);
	tapasco_slot_id_t const slot_id = tapasco_jobs_get_slot(jobs, j_id);
	tapasco_handle_t const iar = tapasco_regs_named_register(dev_ctx, slot_id, TAPASCO_REG_IAR);
	tapasco_handle_t const rh = tapasco_regs_named_register(dev_ctx, slot_id, TAPASCO_REG_RET);
	size_t const num_args = tapasco_jobs_arg_count(jobs, j_id);

	platform_res_t pr = platform_write_ctl(pctx, iar, sizeof(ack_cmd), &ack_cmd,
			PLATFORM_CTL_FLAGS_NONE);

	// ack the interrupt
	if (pr != PLATFORM_SUCCESS) {
		ERR("job #%lu, slot #%lu: could not ack the interrupt: %s (%d)",
				(ul)j_id, (ul)slot_id, platform_strerror(pr), pr);
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}

	pr = platform_read_ctl(pctx, rh, sizeof(ret), &ret, PLATFORM_CTL_FLAGS_NONE);

	if (pr != PLATFORM_SUCCESS) {
		ERR("job #%lu, slot #%lu: could not read return value: %s (%d)",
				(ul)j_id, (ul)slot_id, platform_strerror(pr), pr);
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}

	tapasco_jobs_set_return(jobs, j_id, sizeof(ret), &ret);
	LOG(LALL_SCHEDULER, "job %lu: read result value 0x%08lx", (ul)j_id, (ul)ret);

	// Read back values from all argument registers
	for (size_t a = 0; a < num_args; ++a) {
		tapasco_res_t r       = TAPASCO_SUCCESS;
		tapasco_handle_t h    = tapasco_regs_arg_register(dev_ctx, slot_id, a);
		tapasco_transfer_t *t = tapasco_jobs_get_arg_transfer(jobs, j_id, a);

		r = tapasco_read_arg(dev_ctx, jobs, j_id, h, a);
		if (r != TAPASCO_SUCCESS) { return r; }
		if (t->len > 0) {
			r = tapasco_transfer_from(dev_ctx, jobs, j_id, t, slot_id);
			if (r != TAPASCO_SUCCESS) { return r; }
		}
	}

	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_FINISHED);
	tapasco_pemgmt_release(pemgmt, slot_id);

	return TAPASCO_SUCCESS;
}
