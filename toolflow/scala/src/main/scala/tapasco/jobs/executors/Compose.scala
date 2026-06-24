/*
 *
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
 *
 */
/**
  * @file Compose.scala
  * @brief Threadpool composition task.
  * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
  **/
package tapasco.jobs.executors

import java.util.concurrent.Semaphore

import tapasco.activity.composers.Composer
import tapasco.base._
import tapasco.filemgmt._
import tapasco.jobs.{ComposeJob, HighLevelSynthesisJob}
import tapasco.slurm.Slurm.Completed
import tapasco.task._
import tapasco.slurm._

private object Compose extends Executor[ComposeJob] {
  private implicit val logger = tapasco.Logging.logger(getClass)
  private[this] val _slurm = Slurm.enabled

  def execute(job: ComposeJob)
             (implicit cfg: Configuration, tsk: Tasks): Boolean = {
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

      if (!_slurm) nodeExecution(job) else slurmExecution(job)
    } else {
      logger.error("HLS tasks failed, aborting composition")
      false
    }
  }

  private def nodeExecution(job: ComposeJob)
             (implicit cfg: Configuration, tsk: Tasks): Boolean = {
    val signal = new Semaphore(0)

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
        skipSynth = if (p.name == "sim") Some(true) else job.skipSynthesis,
        effortLevel = job.effortLevel.getOrElse("normal"),
        onComplete = _ => signal.release(),
        deleteOnFail = job.deleteProjects
      )

      composeTasks foreach {
        tsk.apply _
      }

      0 until composeTasks.size foreach { i =>
        signal.acquire()
        logger.debug("Compose task #{} collected", i)
      }

      logger.info("all Compose tasks finished")

      // successful, if all successful
      (composeTasks map (_.result) fold true) (_ && _)
  }

  private def slurmExecution(job: ComposeJob)
             (implicit cfg: Configuration, tsk: Tasks): Boolean = {

    val ComposeJob(c, f, i, _, _, _, _, _, _, _) = job
    val name = c.composition.map(_.kernel).fold("compose")(_ ++ "-" ++ _)
    val outDir = FileAssetManager.TAPASCO_WORK_DIR.resolve("Slurm").resolve("Compose").resolve(name)
    // needed for resource-based scheduling
    val consumer = new ComposeTask(
        composition = c,
        designFrequency = f,
        implementation = Composer.Implementation(i),
        target = Target(job.architectures.head, job.platforms.head),
        onComplete = _ => ()
      )

    // define SLURM job
    val sjob = Slurm.Job(
      name     = name,
      log      = outDir.resolve("tapasco.log"),
      slurmLog = outDir.resolve("slurm-compose.log"),
      errorLog = outDir.resolve("slurm-compose.errors.log"),
      consumer = consumer,
      maxHours = ComposeTask.MAX_COMPOSE_HOURS,
      comment  = Some(outDir.toString),
      job      = job,
      cfg_file = outDir.resolve("slurm-compose.cfg")
    )

    // start slurm job and wait for finish
    Slurm(sjob)(cfg) match {
      case Some(id) => Slurm.waitFor(id) == Completed()
      case None => false
    }
  }
}
