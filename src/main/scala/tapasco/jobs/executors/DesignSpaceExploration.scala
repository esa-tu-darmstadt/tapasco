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
/**
 * @file     DesignSpaceExploration.scala
 * @brief    DesignSpaceExploration executor.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.jobs.executors
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.json._
import  play.api.libs.json._
import  java.util.concurrent.Semaphore

private object DesignSpaceExploration extends Executor[DesignSpaceExplorationJob] {
  private implicit val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  def execute(job: DesignSpaceExplorationJob)
             (implicit cfg: Configuration, tsk: Tasks): Boolean = {
    logger.debug("job: {}", Json.prettyPrint(Json.toJson(job)))
    val signal = new Semaphore(0)

    // first, collect all kernels and trigger HLS if not built yet
    val kernels = job.initialComposition.composition map (_.kernel) toSet

    logger.debug("kernels found in composition: {}", kernels)
    logger.debug("alternative kernels: {}", kernels map (Alternatives.alternatives _))

    val missing = (for {
      k <- kernels
      t <- job.targets
      if FileAssetManager.entities.core(k, t).isEmpty
    } yield (k, t)) ++ (for {
      k <- kernels
      t <- job.targets
      a <- Alternatives.alternatives(k)
      if job.dimensions.alternatives && FileAssetManager.entities.core(a.name, t).isEmpty
    } yield (a.name, t))

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
      val tasks = for {
        a <- job.architectures.toSeq.sortBy(_.name)
        p <- job.platforms.toSeq.sortBy(_.name)
        target = Target(a, p)
      } yield mkExplorationTask(job, target, _ => signal.release())

      tasks foreach { tsk.apply _ }

      0 until tasks.length foreach { i =>
        signal.acquire()
        logger.debug("DSE task #{} collected", i)
      }

      logger.info("all DSE tasks have finished")

      (tasks map (_.result) fold true) (_ && _)
    } else {
      logger.error("HLS tasks failed, aborting composition")
      false
    }
  }

  private def mkExplorationTask(job: DesignSpaceExplorationJob, t: Target, onComplete: Boolean => Unit)
                               (implicit cfg: Configuration, tsk: Tasks): ExplorationTask =
    DesignSpaceExplorationTask(
      job.initialComposition,
      t,
      job.dimensions,
      job.initialFrequency,
      job.heuristic,
      job.batchSize,
      job.basePath map (_.toString),
      job.features,
      None, // logfile
      job.debugMode,
      onComplete
    )
}
