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
#include <platform.h>
#include <platform_status.h>

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
void setup_pes_from_status(tapasco_status_t const *status,
		tapasco_pemgmt_t *p)
{
	for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i) {
		uint32_t id = platform_status_get_slot_id(status, i);
		p->pe[i] = id ? tapasco_pemgmt_create(id, i) : NULL;
	}
}

tapasco_res_t tapasco_pemgmt_init(const tapasco_status_t *status,
		tapasco_pemgmt_t **pemgmt)
{
	tapasco_res_t res = TAPASCO_SUCCESS;
	*pemgmt = (tapasco_pemgmt_t *)malloc(sizeof(tapasco_pemgmt_t));
	if (! pemgmt) return TAPASCO_ERR_OUT_OF_MEMORY;
	memset(*pemgmt, 0, sizeof(**pemgmt));
	assert (status);
	setup_pes_from_status(status, *pemgmt);
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
			platform_write_ctl(gier, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);		// GIER
			// enable ap_done interrupt generation
			platform_write_ctl(ier, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE); 		// IPIER
			// ack all existing interrupts
			platform_read_ctl(iar, sizeof(d), &d, 
				PLATFORM_CTL_FLAGS_NONE);               // IAR
			platform_write_ctl(iar, sizeof(d), &d,
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
	uint32_t ret = 0;
	for (tapasco_slot_id_t i = 0; i < TAPASCO_NUM_SLOTS; ++i)
		ret += ctx->pe[i] ? ctx->pe[i]->id == k_id : 0;
	return ret;
}
