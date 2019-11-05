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
 *  @file tapasco_pemgmt.c
 *  @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <assert.h>
#include <gen_stack.h>
#include <khash.h>
#include <platform.h>
#include <semaphore.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
#include <tapasco_delayed_transfers.h>
#include <tapasco_device.h>
#include <tapasco_errors.h>
#include <tapasco_global.h>
#include <tapasco_jobs.h>
#include <tapasco_logging.h>
#include <tapasco_pemgmt.h>
#include <tapasco_perfc.h>
#include <tapasco_regs.h>

typedef size_t midx_t;

/* Group of PEs by their kernel id. */
struct tapasco_kernel {
  tapasco_kernel_id_t k_id;
  struct gs_t pe_stk; // available PEs
  sem_t sem;          // count av. PEs
};

/* Represents a processing element on the device. */
struct tapasco_pe {
  tapasco_kernel_id_t id;
  tapasco_slot_id_t slot_id;
};
typedef struct tapasco_pe tapasco_pe_t;

/** Initialize the hash map type kernel ids -> index. */
KHASH_MAP_INIT_INT(kidmap, midx_t)

/* Management entity. */
struct tapasco_pemgmt {
  tapasco_dev_id_t dev_id;
  tapasco_pe_t *pe[TAPASCO_NUM_SLOTS];
  struct tapasco_kernel kernel[TAPASCO_NUM_SLOTS];
  khash_t(kidmap) * kidmap;
};

static tapasco_pe_t *tapasco_pemgmt_create_pe(tapasco_kernel_id_t const k_id,
                                              tapasco_slot_id_t const slot_id) {
  tapasco_pe_t *f = (tapasco_pe_t *)calloc(sizeof(tapasco_pe_t), 1);
  f->id = k_id;
  f->slot_id = slot_id;
  return f;
}

static inline void tapasco_pemgmt_destroy_pe(tapasco_pe_t *f) { free(f); }

static void setup_pes_from_status(platform_devctx_t *ctx, tapasco_pemgmt_t *p) {
  midx_t kbucket = 0, bucket_idx;
  int ret;
  khiter_t k;
  for (tapasco_slot_id_t slot = 0; slot < TAPASCO_NUM_SLOTS; ++slot) {
    platform_kernel_id_t const k_id = ctx->info.composition.kernel[slot];
    p->pe[slot] = k_id ? tapasco_pemgmt_create_pe(k_id, slot) : NULL;
    if (p->pe[slot]) {
      k = kh_get(kidmap, p->kidmap, k_id);
      if (k == kh_end(p->kidmap)) {
        k = kh_put(kidmap, p->kidmap, k_id, &ret);
        kh_val(p->kidmap, k) = kbucket;
        sem_init(&p->kernel[kbucket].sem, 0, 0);
        kbucket++;
      }
      bucket_idx = kh_val(p->kidmap, k);
      DEVLOG(ctx->dev_id, LALL_PEMGMT, "k_id " PRIkernel " -> kind #%u", k_id,
             bucket_idx);
      gs_push(&p->kernel[bucket_idx].pe_stk, p->pe[slot]);
      sem_post(&p->kernel[bucket_idx].sem);
    }
  }
  DEVLOG(ctx->dev_id, LALL_PEMGMT, "initialized %d kind%s of PEs", kbucket,
         kbucket > 1 ? "s" : "");
}

tapasco_res_t tapasco_pemgmt_init(const tapasco_devctx_t *devctx,
                                  tapasco_pemgmt_t **pemgmt) {
  tapasco_res_t res = TAPASCO_SUCCESS;
  assert(devctx->pdctx);
  *pemgmt = (tapasco_pemgmt_t *)calloc(sizeof(tapasco_pemgmt_t), 1);
  if (!pemgmt)
    return TAPASCO_ERR_OUT_OF_MEMORY;
  (*pemgmt)->dev_id = devctx->id;
  (*pemgmt)->kidmap = kh_init(kidmap);
  setup_pes_from_status(devctx->pdctx, *pemgmt);
  return res;
}

void tapasco_pemgmt_deinit(tapasco_pemgmt_t *pemgmt) {
  for (khiter_t k = kh_begin(pemgmt->kidmap); k != kh_end(pemgmt->kidmap);
       ++k) {
    if (kh_exist(pemgmt->kidmap, k)) {
      midx_t bucket_idx = kh_val(pemgmt->kidmap, k);
      sem_close(&pemgmt->kernel[bucket_idx].sem);
      while (gs_pop(&pemgmt->kernel[bucket_idx].pe_stk))
        ;
    }
  }
  kh_destroy(kidmap, pemgmt->kidmap);
  for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i)
    tapasco_pemgmt_destroy_pe(pemgmt->pe[i]);
  free(pemgmt);
}

void tapasco_pemgmt_setup_system(tapasco_devctx_t *devctx,
                                 tapasco_pemgmt_t *ctx) {
  assert(ctx);
  uint32_t d = 1;
  tapasco_slot_id_t slot_id = 0;
  platform_devctx_t *pctx = devctx->pdctx;
  tapasco_pe_t **pemgmt = ctx->pe;
  while (slot_id < TAPASCO_NUM_SLOTS) {
    if (*pemgmt) {
      tapasco_handle_t const ier =
          tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_IER);
      tapasco_handle_t const gier =
          tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_GIER);
      tapasco_handle_t const iar =
          tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_IAR);
      // enable IP interrupts
      DEVLOG(devctx->id, LALL_PEMGMT, "writing GIER at " PRIhandle, gier);
      platform_write_ctl(pctx, gier, sizeof(d), &d,
                         PLATFORM_CTL_FLAGS_NONE); // GIER
      // enable ap_done interrupt generation
      DEVLOG(devctx->id, LALL_PEMGMT, "writing IER  at " PRIhandle, ier);
      platform_write_ctl(pctx, ier, sizeof(d), &d,
                         PLATFORM_CTL_FLAGS_NONE); // IPIER
      // ack all existing interrupts
      DEVLOG(devctx->id, LALL_PEMGMT, "writing IAR  at " PRIhandle, iar);
      platform_read_ctl(pctx, iar, sizeof(d), &d,
                        PLATFORM_CTL_FLAGS_NONE); // IAR
      platform_write_ctl(pctx, iar, sizeof(d), &d, PLATFORM_CTL_FLAGS_NONE);
      d = 1;
    }
    ++pemgmt;
    ++slot_id;
  }
}

tapasco_slot_id_t tapasco_pemgmt_acquire_pe(tapasco_pemgmt_t *ctx,
                                            tapasco_kernel_id_t const k_id) {
  const khiter_t k = kh_get(kidmap, ctx->kidmap, k_id);
  assert(k != kh_end(ctx->kidmap));
  const midx_t bucket_idx = kh_val(ctx->kidmap, k);
  while (sem_wait(&ctx->kernel[bucket_idx].sem))
    ;
  tapasco_pe_t *pe = (tapasco_pe_t *)gs_pop(&ctx->kernel[bucket_idx].pe_stk);
  DEVLOG(ctx->dev_id, LALL_PEMGMT, "k_id = " PRIkernel ", slot_id = " PRIslot,
         k_id, pe->slot_id);
  tapasco_perfc_pe_acquired_inc(ctx->dev_id);
  return pe->slot_id;
}

void tapasco_pemgmt_release_pe(tapasco_pemgmt_t *ctx,
                               tapasco_slot_id_t const s_id) {
  assert(s_id >= 0 && s_id < TAPASCO_NUM_SLOTS);
  assert(ctx->pe[s_id]);
  const khiter_t k = kh_get(kidmap, ctx->kidmap, ctx->pe[s_id]->id);
  assert(k != kh_end(ctx->kidmap));
  const midx_t bucket_idx = kh_val(ctx->kidmap, k);
  DEVLOG(ctx->dev_id, LALL_PEMGMT, "slot_id = " PRIslot, s_id);
  tapasco_perfc_pe_released_inc(ctx->dev_id);
  gs_push(&ctx->kernel[bucket_idx].pe_stk, ctx->pe[s_id]);
  while (sem_post(&ctx->kernel[bucket_idx].sem))
    ;
}

size_t tapasco_pemgmt_count(tapasco_pemgmt_t const *ctx,
                            tapasco_kernel_id_t const k_id) {
  size_t ret = 0;
  for (tapasco_slot_id_t i = 0; i < TAPASCO_NUM_SLOTS; ++i)
    ret += ctx->pe[i] ? ctx->pe[i]->id == k_id : 0;
  return ret;
}

size_t tapasco_device_kernel_pe_count(tapasco_devctx_t *devctx,
                                      tapasco_kernel_id_t const k_id) {
  return tapasco_pemgmt_count(devctx->pemgmt, k_id);
}

tapasco_res_t tapasco_pemgmt_prepare_pe(tapasco_devctx_t *devctx,
                                        tapasco_job_id_t const j_id,
                                        tapasco_slot_id_t const slot_id) {
  tapasco_res_t r = TAPASCO_SUCCESS;
  assert(devctx->jobs);
  size_t const num_args = tapasco_jobs_arg_count(devctx->jobs, j_id);
  for (size_t a = 0; a < num_args; ++a) {
    tapasco_handle_t h = tapasco_regs_arg_register(devctx, slot_id, a);
    tapasco_transfer_t *t =
        tapasco_jobs_get_arg_transfer(devctx->jobs, j_id, a);

    if (t->len > 0) {
      DEVLOG(devctx->id, LALL_PEMGMT,
             "job " PRIjob ": transferring %zd byte arg #%zd", j_id, t->len, a);
      if (t->preloaded == 0) {
        if ((r = tapasco_transfer_to(devctx, j_id, t, slot_id)) !=
            TAPASCO_SUCCESS) {
          return r;
        }
      } else {
        DEVLOG(devctx->id, LALL_PEMGMT,
               "Using preloaded data for argument %zd at handle " PRIhandle, a,
               t->handle);
      }
      DEVLOG(devctx->id, LALL_PEMGMT,
             "job " PRIjob ": writing handle to arg #%zd (" PRIhandle ")", j_id,
             a, t->handle);
      if (platform_write_ctl(devctx->pdctx, h, sizeof(t->handle), &t->handle,
                             PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS) {
        return TAPASCO_ERR_PLATFORM_FAILURE;
      }
    } else if ((r = tapasco_write_arg(devctx, devctx->jobs, j_id, h, a)) !=
               TAPASCO_SUCCESS) {
      return r;
    }
  }
  return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_pemgmt_start_pe(tapasco_devctx_t *devctx,
                                      tapasco_slot_id_t const slot_id) {
  uint32_t const start_cmd = 1;
  tapasco_handle_t ctl =
      tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_CTRL);

  if (platform_write_ctl(devctx->pdctx, ctl, sizeof(start_cmd), &start_cmd,
                         PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
    return TAPASCO_ERR_PLATFORM_FAILURE;

  return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_pemgmt_finish_pe(tapasco_devctx_t *devctx,
                                       tapasco_job_id_t const j_id) {
  uint32_t ack_cmd = 1;
  uint64_t ret = 0;
  tapasco_pemgmt_t *pemgmt = devctx->pemgmt;
  tapasco_slot_id_t const slot_id = tapasco_jobs_get_slot(devctx->jobs, j_id);
  tapasco_handle_t const iar =
      tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_IAR);
  tapasco_handle_t const rh =
      tapasco_regs_named_register(devctx, slot_id, TAPASCO_REG_RET);
  size_t const num_args = tapasco_jobs_arg_count(devctx->jobs, j_id);
  tapasco_res_t r = TAPASCO_SUCCESS;

  // ack the interrupt
  platform_res_t pr = platform_write_ctl(devctx->pdctx, iar, sizeof(ack_cmd),
                                         &ack_cmd, PLATFORM_CTL_FLAGS_NONE);

  if (pr != PLATFORM_SUCCESS) {
    DEVERR(devctx->id,
           "job #" PRIjob ", slot #" PRIslot
           ": could not ack the interrupt: %s (" PRIres ")",
           j_id, slot_id, platform_strerror(pr), pr);
    return TAPASCO_ERR_PLATFORM_FAILURE;
  }

  pr = platform_read_ctl(devctx->pdctx, rh, sizeof(ret), &ret,
                         PLATFORM_CTL_FLAGS_NONE);

  if (pr != PLATFORM_SUCCESS) {
    DEVERR(devctx->id,
           "job #" PRIjob ", slot #" PRIslot
           ": could not read return value: %s (" PRIres ")",
           j_id, slot_id, platform_strerror(pr), pr);
    return TAPASCO_ERR_PLATFORM_FAILURE;
  }

  tapasco_jobs_set_return(devctx->jobs, j_id, sizeof(ret), &ret);
  DEVLOG(devctx->id, LALL_PEMGMT, "job #" PRIjob ": read result value 0x%08llx",
         j_id, ret);

  // Read back values from all argument registers
  for (size_t a = 0; a < num_args; ++a) {
    tapasco_handle_t h = tapasco_regs_arg_register(devctx, slot_id, a);
    tapasco_transfer_t *t =
        tapasco_jobs_get_arg_transfer(devctx->jobs, j_id, a);

    if ((r = tapasco_read_arg(devctx, devctx->jobs, j_id, h, a)) !=
        TAPASCO_SUCCESS) {
      return r;
    }
    if (t->len > 0) {
      r = tapasco_transfer_from(devctx, devctx->jobs, j_id, t, slot_id);
      if (r != TAPASCO_SUCCESS) {
        return r;
      }
    }
  }

  tapasco_pemgmt_release_pe(pemgmt, slot_id);
  return TAPASCO_SUCCESS;
}
