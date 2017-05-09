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
//! @file	tpc_scheduler.h
//! @brief	Defines micro API for job scheduling on hardware threadpools.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __TPC_SCHEDULER_H__
#define __TPC_SCHEDULER_H__

#include <tpc_api.h>
#include <tpc_jobs.h>
#include <tpc_functions.h>

/**
 * Schedule a job for execution on the hardware threadpool.
 * @param dev_ctx device context.
 * @param jobs jobs context.
 * @param functions functions context.
 * @param j_id job id.
 * @return TPC_SUCCESS, if job could be scheduled and will execute.
 **/
tpc_res_t tpc_scheduler_launch(
		tpc_dev_ctx_t *dev_ctx,
		tpc_jobs_t *jobs,
		tpc_functions_t *functions,
		tpc_job_id_t const j_id);

#endif /* __TPC_SCHEDULER_H__ */

