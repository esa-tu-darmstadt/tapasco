//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TAPASCO).
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
/** @file	tapasco_delayed_transfers.c
 *  @brief	Functions for delayed memory transfers.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TAPASCO_DELAYED_TRANSFERS_H__
#define TAPASCO_DELAYED_TRANSFERS_H__

#include <tapasco_jobs.h>
#include <tapasco_types.h>

tapasco_res_t tapasco_transfer_to(tapasco_devctx_t *dev_ctx,
                                  tapasco_job_id_t const j_id,
                                  tapasco_transfer_t *t,
                                  tapasco_slot_id_t s_id);

tapasco_res_t tapasco_transfer_from(tapasco_devctx_t *dev_ctx,
                                    tapasco_jobs_t *jobs,
                                    tapasco_job_id_t const j_id,
                                    tapasco_transfer_t *t,
                                    tapasco_slot_id_t s_id);

tapasco_res_t tapasco_write_arg(tapasco_devctx_t *dev_ctx, tapasco_jobs_t *jobs,
                                tapasco_job_id_t const j_id,
                                tapasco_handle_t const h, size_t const a);

tapasco_res_t tapasco_read_arg(tapasco_devctx_t *dev_ctx, tapasco_jobs_t *jobs,
                               tapasco_job_id_t const j_id,
                               tapasco_handle_t const h, size_t const a);

#endif /* TAPASCO_DELAYED_TRANSFERS_H__ */
