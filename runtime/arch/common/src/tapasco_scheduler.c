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
/** @file tapasco_scheduler.c
 *  @brief  Primitive scheduler.
 *  @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <assert.h>
#include <platform.h>
#include <tapasco_device.h>
#include <tapasco_logging.h>
#include <tapasco_pemgmt.h>
#include <tapasco_perfc.h>
#include <tapasco_regs.h>
#include <tapasco_scheduler.h>
#include <tapasco_delayed_transfers.h>
#include <unistd.h>

tapasco_res_t tapasco_scheduler_launch(tapasco_devctx_t *devctx,
                                       tapasco_job_id_t const j_id) {
  assert(devctx->jobs);
  tapasco_kernel_id_t const k_id =
    tapasco_jobs_get_kernel_id(devctx->jobs, j_id);
  tapasco_slot_id_t slot_id;
  tapasco_res_t r;

  DEVLOG(devctx->id, LALL_SCHEDULER, "Preloading transfers for Job %d", j_id);
  size_t const num_args = tapasco_jobs_arg_count(devctx->jobs, j_id);
  for (size_t a = 0; a < num_args; ++a) {
    tapasco_transfer_t *t = tapasco_jobs_get_arg_transfer(devctx->jobs, j_id, a);

    if (t->len && !(t->flags & TAPASCO_DEVICE_COPY_PE_LOCAL)) {
      if ((r = tapasco_transfer_to(devctx, j_id, t, 0)) != TAPASCO_SUCCESS) {
        DEVLOG(devctx->id, LALL_SCHEDULER, "Failed to preload transfer");
      } else {
        t->preloaded = 1;
      }
    } else {
      DEVLOG(devctx->id, LALL_SCHEDULER, "Can not preload local memory");
    }
  }

  DEVLOG(devctx->id, LALL_SCHEDULER,
         "job " PRIjob ": launching for kernel " PRIkernel
         ", acquiring PE ... ",
         j_id, k_id);

  slot_id = tapasco_pemgmt_acquire_pe(devctx->pemgmt, k_id);
  if (slot_id < 0 || slot_id >= TAPASCO_NUM_SLOTS) {
    DEVERR(devctx->id, "received illegal slot id #%u", slot_id);
    return TAPASCO_ERR_INVALID_SLOT_ID;
  }
  DEVLOG(devctx->id, LALL_SCHEDULER, "job " PRIjob ": got PE " PRIslot, j_id,
         slot_id);

#ifndef NPERFC
  if (slot_id > tapasco_perfc_pe_high_watermark_get(devctx->id))
    tapasco_perfc_pe_high_watermark_set(devctx->id, _slot_high_watermark);
#endif

  DEVLOG(devctx->id, LALL_SCHEDULER,
         "job " PRIjob ": preparing slot #" PRIslot " ...", j_id, slot_id);
  if ((r = tapasco_pemgmt_prepare_pe(devctx, j_id, slot_id)) !=
      TAPASCO_SUCCESS) {
    DEVERR(devctx->id,
           "could not prepare slot #" PRIslot " for job #" PRIjob
           ": %s (" PRIres ")",
           slot_id, j_id, tapasco_strerror(r), r);
    return r;
  }

  DEVLOG(devctx->id, LALL_SCHEDULER,
         "job " PRIjob ": starting PE in slot #" PRIslot " ...", j_id, slot_id);
  tapasco_jobs_set_slot(devctx->jobs, j_id, slot_id);

  if ((r = tapasco_pemgmt_start_pe(devctx, slot_id)) != TAPASCO_SUCCESS) {
    DEVERR(devctx->id,
           "could not start PE in slot #" PRIslot ": %s (" PRIres ")", slot_id,
           tapasco_strerror(r), r);
    return r;
  }

  tapasco_perfc_jobs_launched_inc(devctx->id);
  return TAPASCO_SUCCESS;
}

inline tapasco_res_t tapasco_device_job_collect(tapasco_devctx_t *devctx,
    tapasco_job_id_t const job_id) {
  return tapasco_scheduler_finish_job(devctx, job_id);
}

tapasco_res_t tapasco_scheduler_finish_job(tapasco_devctx_t *devctx,
    tapasco_job_id_t const j_id) {
  platform_res_t pr;
  const tapasco_slot_id_t slot_id = tapasco_jobs_get_slot(devctx->jobs, j_id);
  DEVLOG(devctx->id, LALL_SCHEDULER,
         "job " PRIjob ":  waiting for slot #" PRIslot " ...", j_id, slot_id);
  tapasco_perfc_waiting_for_job_set(devctx->id, j_id);
  if ((pr = platform_wait_for_slot(devctx->pdctx, slot_id)) !=
      PLATFORM_SUCCESS) {
    DEVERR(devctx->id, "waiting for job #" PRIjob " failed: %s (" PRIres ")",
           j_id, platform_strerror(pr), pr);
    return TAPASCO_ERR_PLATFORM_FAILURE;
  }
  tapasco_perfc_waiting_for_job_set(devctx->id, 0);
  DEVLOG(devctx->id, LALL_SCHEDULER,
         "job " PRIjob ": returned successfully from waiting", j_id);
  tapasco_perfc_jobs_completed_inc(devctx->id);
  return tapasco_pemgmt_finish_pe(devctx, j_id);
}
