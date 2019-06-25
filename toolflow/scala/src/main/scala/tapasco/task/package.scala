//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
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
package de.tu_darmstadt.cs.esa.tapasco

/**
 * Contains routines to launch parallel jobs and tasks via resource-aware scheduler.
 * The `task` package contains the main organization of parallel jobs in TPC: Each
 * [[Task]] implementation can be scheduled via [[Tasks]] instances, which contain
 * a [[ResourceMonitor]] to launch jobs only if their resource requirements are met.
 *
 * Jobs can also implement SLURM-support and launch their jobs as separate processes
 * using the SLURM compute cluster interface. Examples: [[HighLevelSynthesisTask]],
 * [[ComposeTask]].
 **/
package object task
