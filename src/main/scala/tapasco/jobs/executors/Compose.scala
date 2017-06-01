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
 * @file     Compose.scala
 * @brief    Threadpool composition task.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.jobs.executors
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.{ComposeJob, HighLevelSynthesisJob}
import  java.util.concurrent.Semaphore

private object Compose extends Executor[ComposeJob] {
  private implicit val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  def execute(job: ComposeJob)
             (implicit cfg: Configuration, tsk: Tasks): Boolean = {
    val signal = new Semaphore(0)

    logger.trace("composition: {}", job.composition)

    // first, collect all kernels and trigger HLS if not built yet
    val kernels = job.composition.composition map (_.kernel) toSet

    logger.debug("kernels found in compositions: {}", kernels)

    val missing = for {
      k <- kernels
      t <- job.targets
      if FileAssetManager.entities.core(k, t).isEmpty
    } yield (k, t)

    if (missing.nonEmpty) {
      logger.info("need to synthesize the following cores first: {}",
        missing map { case (k, t) => "%s @ %s".format(k, t) } mkString ", ")
    }

    val hls_results = missing map { case (k, t) =>
      // run HLS job for this kernel and target
      HighLevelSynthesisJob(
        "VivadoHLS", // FIXME
        Some(Seq(t.ad.name)),
        Some(Seq(t.pd.name)),
        Some(Seq(k))
      ).execute
    }

    val hls_ok = (hls_results fold true) (_ && _)

    if (hls_ok) {
      logger.info("all HLS tasks finished successfully, beginning compose run...")
      logger.debug("job: {}", job)

      val composeTasks = for {
        p <- job.platforms
        a <- job.architectures
        t = Target(a, p)
      } yield new ComposeTask(
          composition = job.composition,
          designFrequency = job.designFrequency,
          implementation = job.implementation,
          target = t,
          features = job.features,
          debugMode = job.debugMode,
          onComplete = _ => signal.release())

      composeTasks foreach { tsk.apply _ }

      0 until composeTasks.size foreach { i =>
        signal.acquire()
        logger.debug("Compose task #{} collected", i)
      }

      logger.info("all Compose tasks finished")

      // successful, if all successful
      (composeTasks map (_.result) fold true) (_ && _)
    } else {
      logger.error("HLS tasks failed, aborting composition")
      false
    }
  }
}

