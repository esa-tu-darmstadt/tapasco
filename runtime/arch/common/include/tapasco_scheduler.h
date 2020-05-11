/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
//! @file	tapasco_scheduler.h
//! @brief	Defines micro API for job scheduling on hardware threadpools.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_SCHEDULER_H__
#define TAPASCO_SCHEDULER_H__

#include <tapasco_jobs.h>
#include <tapasco_pemgmt.h>
#include <tapasco_types.h>

/**
 * Schedule a job for execution on the hardware threadpool.
 * @param dev_ctx device context.
 * @param j_id job id.
 * @return TAPASCO_SUCCESS, if job could be scheduled and will execute, an error
 *code otherwise.
 **/
tapasco_res_t tapasco_scheduler_launch(tapasco_devctx_t *dev_ctx,
                                       tapasco_job_id_t const j_id);

/**
 * Wait for given job and fetch results.
 * @param dev_ctx device context.
 * @param j_id job id.
 * @return TAPASCO_SUCCESS, if job could be scheduled and will execute, an error
 *code otherwise.
 **/
tapasco_res_t tapasco_scheduler_finish_job(tapasco_devctx_t *dev_ctx,
                                           tapasco_job_id_t const j_id);

#endif /* TAPASCO_SCHEDULER_H__ */
