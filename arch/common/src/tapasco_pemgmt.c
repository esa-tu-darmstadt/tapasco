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
#include <stdatomic.h>
#include <string.h>
#include <assert.h>
#include <semaphore.h>
#include <tapasco_pemgmt.h>
#include <tapasco_device.h>
#include <tapasco_errors.h>
#include <tapasco_regs.h>
#include <tapasco_logging.h>
#include <tapasco_global.h>
#include <tapasco_jobs.h>
#include <tapasco_delayed_transfers.h>
#include <tapasco_perfc.h>
#include <platform.h>
#include <gen_stack.h>
#include <khash.h>

/** State of PEs, e.g., busy or idle. */
typedef enum {
	TAPASCO_PE_STATE_IDLE 					= 1,
	TAPASCO_PE_STATE_READY,
	TAPASCO_PE_STATE_BUSY,
	TAPASCO_PE_STATE_DONE
} tapasco_pe_state_t;

/** Represents a processing element on the device. */
struct tapasco_pe {
	tapasco_kernel_id_t 			id;
	tapasco_slot_id_t 			slot_id;
	_Atomic tapasco_pe_state_t 		state;
};
typedef struct tapasco_pe tapasco_pe_t;

static
tapasco_pe_t *tapasco_pemgmt_create(tapasco_kernel_id_t const k_id,
		tapasco_slot_id_t const slot_id)
{
	tapasco_pe_t *f = (tapasco_pe_t *)calloc(sizeof(tapasco_pe_t), 1);
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
	tapasco_dev_id_t			dev_id;
	tapasco_pe_t 				*pe[TAPASCO_NUM_SLOTS];
};

KHASH_MAP_INIT_INT(kidmap, uint8_t)
static khash_t(kidmap) *_kidmap = NULL;

struct tapasco_kernel {
	tapasco_kernel_id_t k_id;
	struct gs_t pe_stk;
	sem_t sem;
};

static
struct tapasco_kernel _kernels[PLATFORM_NUM_SLOTS];

static
void setup_pes_from_status(platform_devctx_t *ctx, tapasco_pemgmt_t *p)
{
	size_t kbucket = 0;
	uint8_t bucket_idx;
	int ret;
	_kidmap = kh_init(kidmap);
	khiter_t k;
	for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i) {
		platform_kernel_id_t const k_id = ctx->info.composition.kernel[i];
		p->pe[i] = k_id ? tapasco_pemgmt_create(k_id, i) : NULL;
		if (p->pe[i]) {
			k = kh_get(kidmap, _kidmap, k_id);
			if (k == kh_end(_kidmap)) {
				k = kh_put(kidmap, _kidmap, k_id, &ret);
				kh_val(_kidmap, k) = kbucket;
				sem_init(&_kernels[kbucket].sem, 0, 0);
				kbucket++;
			}
			bucket_idx = kh_val(_kidmap, k);
			DEVLOG(ctx->dev_id, LALL_PEMGMT, "k_id %u -> %u", k_id, bucket_idx);
			gs_push(&_kernels[bucket_idx].pe_stk, p->pe[i]);
			sem_post(&_kernels[bucket_idx].sem);
		}
	}
}

tapasco_res_t tapasco_pemgmt_init(const tapasco_devctx_t *devctx, tapasco_pemgmt_t **pemgmt)
{
	tapasco_res_t res = TAPASCO_SUCCESS;
	assert(devctx->pdctx);
	*pemgmt = (tapasco_pemgmt_t *)calloc(sizeof(tapasco_pemgmt_t), 1);
	if (! pemgmt) return TAPASCO_ERR_OUT_OF_MEMORY;
	memset(*pemgmt, 0, sizeof(**pemgmt));
	setup_pes_from_status(devctx->pdctx, *pemgmt);
	(*pemgmt)->dev_id = devctx->id;
	return res;
}

void tapasco_pemgmt_deinit(tapasco_pemgmt_t *pemgmt)
{
	for (khiter_t k = kh_begin(_kidmap); k != kh_end(_kidmap); ++k) {
		uint8_t bucket_idx = kh_val(_kidmap, k);
		while (gs_pop(&_kernels[bucket_idx].pe_stk)) ;
		sem_close(&_kernels[bucket_idx].sem);
	}
	for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i)
		tapasco_pemgmt_destroy(pemgmt->pe[i]);
	free(pemgmt);
}

void tapasco_pemgmt_setup_system(tapasco_devctx_t *devctx, tapasco_pemgmt_t *ctx)
{
	assert (ctx);
	uint32_t d = 1;
	tapasco_slot_id_t slot_id = 0;
	platform_devctx_t *pctx = devctx->pdctx;
	tapasco_pe_t **pemgmt = ctx->pe;
	while (slot_id < TAPASCO_NUM_SLOTS) {
		if (*pemgmt) {
			tapasco_handle_t const ier = tapasco_regs_named_register(
				devctx, slot_id, TAPASCO_REG_IER);
			tapasco_handle_t const gier = tapasco_regs_named_register(
				devctx, slot_id, TAPASCO_REG_GIER);
			tapasco_handle_t const iar = tapasco_regs_named_register(
				devctx, slot_id, TAPASCO_REG_IAR);
			// enable IP interrupts
			LOG(LALL_PEMGMT, "writing GIER at 0x%08lx", (unsigned long)gier);
			platform_write_ctl(pctx, gier, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);		// GIER
			// enable ap_done interrupt generation
			LOG(LALL_PEMGMT, "writing IER at 0x%08lx", (unsigned long)ier);
			platform_write_ctl(pctx, ier, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE); 		// IPIER
			// ack all existing interrupts
			LOG(LALL_PEMGMT, "writing IAR at 0x%08lx", (unsigned long)iar);
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
int reserve_pe(tapasco_dev_id_t const dev_id, tapasco_pe_t *pe, tapasco_kernel_id_t const k_id)
{
	assert(pe != NULL);
	const tapasco_pe_state_t old_state = TAPASCO_PE_STATE_IDLE;
	if (pe->id != k_id) {
	  tapasco_perfc_reserve_pe_wrong_kernel_inc(dev_id);
	} else if (! atomic_compare_exchange_strong(&pe->state, &old_state, TAPASCO_PE_STATE_BUSY)) {
	  tapasco_perfc_reserve_pe_wrong_state_inc(dev_id);
	  return 0;
	}
	return 1;
}

tapasco_slot_id_t tapasco_pemgmt_acquire(tapasco_pemgmt_t *ctx,
		tapasco_kernel_id_t const k_id)
{
	uint8_t bucket_idx = kh_val(_kidmap, k_id);
	while (sem_wait(&_kernels[bucket_idx].sem)) ;
	tapasco_pe_t *pe = (tapasco_pe_t *)gs_pop(&_kernels[bucket_idx].pe_stk);
	LOG(LALL_PEMGMT, "k_id = %d, slotid = %d", k_id, pe->slot_id);
	tapasco_perfc_pe_acquired_inc(ctx->dev_id);
	return pe->slot_id;
}

inline
void tapasco_pemgmt_release(tapasco_pemgmt_t *ctx, tapasco_slot_id_t const s_id)
{
	uint8_t bucket_idx = kh_val(_kidmap, ctx->pe[s_id]->slot_id);
	assert(s_id >= 0 && s_id < TAPASCO_NUM_SLOTS);
	assert(ctx->pe[s_id]);
	LOG(LALL_PEMGMT, "slotid = %d", s_id);
	tapasco_perfc_pe_released_inc(ctx->dev_id);
	//atomic_store(&ctx->pe[s_id]->state, TAPASCO_PE_STATE_IDLE);
	gs_push(&_kernels[bucket_idx].pe_stk, ctx->pe[s_id]);
	sem_post(&_kernels[bucket_idx].sem);
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

size_t tapasco_device_kernel_pe_count(tapasco_devctx_t *devctx,
		tapasco_kernel_id_t const k_id)
{
	return tapasco_pemgmt_count(devctx->pemgmt, k_id);

}

tapasco_res_t tapasco_pemgmt_start(tapasco_devctx_t *devctx, tapasco_slot_id_t const slot_id)
{
	uint32_t const start_cmd = 1;
	tapasco_handle_t ctl = tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_CTRL);

	if (platform_write_ctl(devctx->pdctx,
			ctl,
			sizeof(start_cmd),
			&start_cmd,
			PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_ERR_PLATFORM_FAILURE;

	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_pemgmt_prepare_slot(tapasco_devctx_t *devctx,
		tapasco_job_id_t const j_id,
		tapasco_slot_id_t const slot_id)
{
	assert(devctx->jobs);
	size_t const num_args   = tapasco_jobs_arg_count(devctx->jobs, j_id);
	for (size_t a = 0; a < num_args; ++a) {
		tapasco_res_t r       = TAPASCO_SUCCESS;
		tapasco_handle_t h    = tapasco_regs_arg_register(devctx, slot_id, a);
		tapasco_transfer_t *t = tapasco_jobs_get_arg_transfer(devctx->jobs, j_id, a);

		if (t->len > 0) {
			LOG(LALL_PEMGMT, "job %lu: transferring %zd byte arg #%zd",
					(unsigned long)j_id, t->len, a);
			r = tapasco_transfer_to(devctx, j_id, t, slot_id);
			if (r != TAPASCO_SUCCESS) { return r; }
			LOG(LALL_PEMGMT, "job %lu: writing handle to arg #%zd (0x%08x)",
					(unsigned long)j_id, a, t->handle);
			if (platform_write_ctl(devctx->pdctx, h, sizeof(t->handle),
					&t->handle, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
				return TAPASCO_ERR_PLATFORM_FAILURE;
		} else {
			tapasco_res_t r = tapasco_write_arg(devctx, devctx->jobs, j_id, h, a);
			if (r != TAPASCO_SUCCESS) { return r; }
		}
	}
	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_pemgmt_finish_job(tapasco_devctx_t *devctx,
		tapasco_job_id_t const j_id)
{
	uint32_t ack_cmd = 1;
	uint64_t ret = 0;
	tapasco_pemgmt_t *pemgmt = devctx->pemgmt;
	tapasco_slot_id_t const slot_id = tapasco_jobs_get_slot(devctx->jobs, j_id);
	tapasco_handle_t const iar = tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_IAR);
	tapasco_handle_t const rh = tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_RET);
	size_t const num_args = tapasco_jobs_arg_count(devctx->jobs, j_id);

	platform_res_t pr = platform_write_ctl(devctx->pdctx, iar, sizeof(ack_cmd), &ack_cmd,
			PLATFORM_CTL_FLAGS_NONE);

	// ack the interrupt
	if (pr != PLATFORM_SUCCESS) {
		ERR("job #%lu, slot #%lu: could not ack the interrupt: %s (%d)",
				(ul)j_id, (ul)slot_id, platform_strerror(pr), pr);
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}

	pr = platform_read_ctl(devctx->pdctx, rh, sizeof(ret), &ret, PLATFORM_CTL_FLAGS_NONE);

	if (pr != PLATFORM_SUCCESS) {
		ERR("job #%lu, slot #%lu: could not read return value: %s (%d)",
				(ul)j_id, (ul)slot_id, platform_strerror(pr), pr);
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}

	tapasco_jobs_set_return(devctx->jobs, j_id, sizeof(ret), &ret);
	LOG(LALL_SCHEDULER, "job %lu: read result value 0x%08lx", (ul)j_id, (ul)ret);

	// Read back values from all argument registers
	for (size_t a = 0; a < num_args; ++a) {
		tapasco_res_t r       = TAPASCO_SUCCESS;
		tapasco_handle_t h    = tapasco_regs_arg_register(devctx, slot_id, a);
		tapasco_transfer_t *t = tapasco_jobs_get_arg_transfer(devctx->jobs, j_id, a);

		r = tapasco_read_arg(devctx, devctx->jobs, j_id, h, a);
		if (r != TAPASCO_SUCCESS) { return r; }
		if (t->len > 0) {
			r = tapasco_transfer_from(devctx, devctx->jobs, j_id, t, slot_id);
			if (r != TAPASCO_SUCCESS) { return r; }
		}
	}

	tapasco_jobs_set_state(devctx->jobs, j_id, TAPASCO_JOB_STATE_FINISHED);
	tapasco_pemgmt_release(pemgmt, slot_id);

	return TAPASCO_SUCCESS;
}
