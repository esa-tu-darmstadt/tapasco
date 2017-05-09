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
