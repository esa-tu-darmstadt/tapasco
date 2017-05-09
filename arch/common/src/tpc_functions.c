//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 *  @file	tpc_functions.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <tpc_functions.h>
#include <tpc_device.h>
#include <tpc_errors.h>
#include <tpc_address_map.h>
#include <tpc_logging.h>
#include <tpc_status.h>
#include <platform_api.h>

/** State of functions, e.g., busy or idle. */
typedef enum {
	TPC_FUNC_STATE_IDLE 				= 1,
	TPC_FUNC_STATE_READY,
	TPC_FUNC_STATE_BUSY,
	TPC_FUNC_STATE_DONE
} tpc_func_state_t;

/** Represents a function (i.e., kernel instance) on the device. */
typedef struct tpc_func tpc_func_t;
struct tpc_func {
	tpc_func_id_t id;
	tpc_func_slot_id_t slot_id;
	tpc_func_state_t state;
};

static tpc_func_t *tpc_functions_create(tpc_func_id_t const func_id,
		tpc_func_slot_id_t const slot_id) {
	tpc_func_t *f = (tpc_func_t *)malloc(sizeof(tpc_func_t));
	f->id = func_id;
	f->slot_id = slot_id;
	f->state = TPC_FUNC_STATE_IDLE;
	return f;
}

static inline void tpc_functions_destroy(tpc_func_t *f) {
	free(f);
}

/******************************************************************************/

struct tpc_functions {
	tpc_func_t *func[TPC_MAX_INSTANCES];
};

static void setup_functions_from_status(tpc_status_t const *status,
		tpc_functions_t *p) {
	for (int i = 0; i < TPC_MAX_INSTANCES; ++i)
		p->func[i] = status->id[i] ? tpc_functions_create(status->id[i], i) : NULL;
}

tpc_res_t tpc_functions_init(tpc_functions_t **funcs) {
	tpc_res_t res = TPC_SUCCESS;
	*funcs = (tpc_functions_t *)malloc(sizeof(tpc_functions_t));
	if (! funcs) return TPC_ERR_OUT_OF_MEMORY;
	memset(*funcs, 0, sizeof(tpc_functions_t));
	tpc_status_t *status = NULL;
	res = tpc_status_init(&status);
	if (res == TPC_SUCCESS)
		setup_functions_from_status(status, *funcs);
	tpc_status_deinit(status);
	return res;
}

void tpc_functions_deinit(tpc_functions_t *funcs) {
	for (int i = 0; i < TPC_MAX_INSTANCES; ++i)
		tpc_functions_destroy(funcs->func[i]);
	free(funcs);
}

void tpc_functions_setup_system(tpc_dev_ctx_t *dev_ctx, tpc_functions_t *ctx) {
	assert (ctx);
	uint32_t d = 1, slot_id = 0;
	tpc_func_t **funcs = ctx->func;
	while (slot_id < TPC_MAX_INSTANCES) {
		if (*funcs) {
			tpc_handle_t const h = tpc_address_map_func_reg(
				dev_ctx, slot_id, TPC_FUNC_REG_BASE) + 0x4;
			// enable IP interrupts
			platform_write_ctl(h, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);		// GIER
			// enable ap_done interrupt generation
			platform_write_ctl(h + 0x4, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE); 		// IPIER
			// ack all existing interrupts
			platform_read_ctl(tpc_address_map_func_reg(dev_ctx,
				slot_id, TPC_FUNC_REG_IAR), sizeof(d), &d, 
				PLATFORM_CTL_FLAGS_NONE);
			platform_write_ctl(tpc_address_map_func_reg(dev_ctx,
				slot_id, TPC_FUNC_REG_IAR), sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);
			d = 1;
		}
		++funcs;
		++slot_id;
	}
	
}

inline static int reserve_func(tpc_func_t *f, tpc_func_id_t const f_id) {
	assert(f != NULL);
	return f->id == f_id && __sync_bool_compare_and_swap(&f->state,
			TPC_FUNC_STATE_IDLE, TPC_FUNC_STATE_BUSY);
}

tpc_func_slot_id_t tpc_functions_acquire(tpc_functions_t *ctx,
		tpc_func_id_t const f_id) {
	tpc_func_t **funcs = ctx->func;
	int len = TPC_MAX_INSTANCES;
	while (len && ! reserve_func(*funcs, f_id) && (*funcs)->id) {
		--len;
		++funcs;
	}
	LOG(LALL_FUNCTIONS, "func_id = %d, slotid = %d",
			f_id, len > 0  ? (*funcs)->slot_id : -1);
	return len > 0 ? (*funcs)->slot_id : -1;
}

inline
void tpc_functions_release(tpc_functions_t *ctx, tpc_func_slot_id_t const s_id) {
	assert(ctx);
	assert(ctx->func[s_id]);
	LOG(LALL_FUNCTIONS, "slotid = %d", s_id);
	ctx->func[s_id]->state = TPC_FUNC_STATE_IDLE;
}

inline
uint32_t tpc_functions_count(tpc_functions_t const *ctx, tpc_func_id_t const f_id) {
	uint32_t ret = 0;
	for (int i = 0; i < TPC_MAX_INSTANCES; ++i)
		ret += ctx->func[i] ? ctx->func[i]->id == f_id : 0;
	return ret;
}

