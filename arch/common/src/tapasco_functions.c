//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
 *  @file	tapasco_functions.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <tapasco_functions.h>
#include <tapasco_device.h>
#include <tapasco_errors.h>
#include <tapasco_address_map.h>
#include <tapasco_logging.h>
#include <platform.h>

/** State of functions, e.g., busy or idle. */
typedef enum {
	TAPASCO_FUNC_STATE_IDLE 				= 1,
	TAPASCO_FUNC_STATE_READY,
	TAPASCO_FUNC_STATE_BUSY,
	TAPASCO_FUNC_STATE_DONE
} tapasco_func_state_t;

/** Represents a function (i.e., kernel instance) on the device. */
typedef struct tapasco_func tapasco_func_t;
struct tapasco_func {
	tapasco_func_id_t id;
	tapasco_func_slot_id_t slot_id;
	tapasco_func_state_t state;
};

static tapasco_func_t *tapasco_functions_create(tapasco_func_id_t const func_id,
		tapasco_func_slot_id_t const slot_id) {
	tapasco_func_t *f = (tapasco_func_t *)malloc(sizeof(tapasco_func_t));
	f->id = func_id;
	f->slot_id = slot_id;
	f->state = TAPASCO_FUNC_STATE_IDLE;
	return f;
}

static inline void tapasco_functions_destroy(tapasco_func_t *f) {
	free(f);
}

/******************************************************************************/

struct tapasco_functions {
	tapasco_func_t *func[TAPASCO_MAX_INSTANCES];
};

static void setup_functions_from_status(tapasco_status_t const *status,
		tapasco_functions_t *p) {
	for (int i = 0; i < TAPASCO_MAX_INSTANCES; ++i)
		p->func[i] = status->id[i] ? tapasco_functions_create(status->id[i], i) : NULL;
}

tapasco_res_t tapasco_functions_init(const tapasco_status_t *status, tapasco_functions_t **funcs) {
	tapasco_res_t res = TAPASCO_SUCCESS;
	*funcs = (tapasco_functions_t *)malloc(sizeof(tapasco_functions_t));
	if (! funcs) return TAPASCO_ERR_OUT_OF_MEMORY;
	memset(*funcs, 0, sizeof(tapasco_functions_t));
	assert (status);
	setup_functions_from_status(status, *funcs);
	return res;
}

void tapasco_functions_deinit(tapasco_functions_t *funcs) {
	for (int i = 0; i < TAPASCO_MAX_INSTANCES; ++i)
		tapasco_functions_destroy(funcs->func[i]);
	free(funcs);
}

void tapasco_functions_setup_system(tapasco_dev_ctx_t *dev_ctx, tapasco_functions_t *ctx) {
	assert (ctx);
	uint32_t d = 1, slot_id = 0;
	tapasco_func_t **funcs = ctx->func;
	while (slot_id < TAPASCO_MAX_INSTANCES) {
		if (*funcs) {
			tapasco_handle_t const h = tapasco_address_map_func_reg(
				dev_ctx, slot_id, TAPASCO_FUNC_REG_BASE) + 0x4;
			// enable IP interrupts
			platform_write_ctl(h, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);		// GIER
			// enable ap_done interrupt generation
			platform_write_ctl(h + 0x4, sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE); 		// IPIER
			// ack all existing interrupts
			platform_read_ctl(tapasco_address_map_func_reg(dev_ctx,
				slot_id, TAPASCO_FUNC_REG_IAR), sizeof(d), &d, 
				PLATFORM_CTL_FLAGS_NONE);
			platform_write_ctl(tapasco_address_map_func_reg(dev_ctx,
				slot_id, TAPASCO_FUNC_REG_IAR), sizeof(d), &d,
				PLATFORM_CTL_FLAGS_NONE);
			d = 1;
		}
		++funcs;
		++slot_id;
	}

}

inline static int reserve_func(tapasco_func_t *f, tapasco_func_id_t const f_id) {
	assert(f != NULL);
	return f->id == f_id && __sync_bool_compare_and_swap(&f->state,
			TAPASCO_FUNC_STATE_IDLE, TAPASCO_FUNC_STATE_BUSY);
}

tapasco_func_slot_id_t tapasco_functions_acquire(tapasco_functions_t *ctx,
		tapasco_func_id_t const f_id) {
	tapasco_func_t **funcs = ctx->func;
	int len = TAPASCO_MAX_INSTANCES;
	while (len && *funcs && ! reserve_func(*funcs, f_id) && (*funcs)->id) {
		--len;
		++funcs;
	}
	LOG(LALL_FUNCTIONS, "func_id = %d, slotid = %d",
			f_id, len > 0 && funcs && *funcs  ? (*funcs)->slot_id : -1);
	return len > 0 && *funcs ? (*funcs)->slot_id : -1;
}

inline
void tapasco_functions_release(tapasco_functions_t *ctx, tapasco_func_slot_id_t const s_id) {
	assert(ctx);
	assert(ctx->func[s_id]);
	LOG(LALL_FUNCTIONS, "slotid = %d", s_id);
	ctx->func[s_id]->state = TAPASCO_FUNC_STATE_IDLE;
}

inline
uint32_t tapasco_functions_count(tapasco_functions_t const *ctx, tapasco_func_id_t const f_id) {
	uint32_t ret = 0;
	for (int i = 0; i < TAPASCO_MAX_INSTANCES; ++i)
		ret += ctx->func[i] ? ctx->func[i]->id == f_id : 0;
	return ret;
}

