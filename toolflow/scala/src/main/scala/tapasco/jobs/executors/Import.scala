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
  * @file Import.scala
  * @brief Task to add an existing IP core to the TPC catalog. Will perform
  *        evaluation of the core with the current configuration parameters
  *        (i.e., it will perform evaluation for all configured Architectures
  *        and Platforms).
  * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
  **/
package tapasco.jobs.executors

import java.util.concurrent.Semaphore

import tapasco.base._
import tapasco.filemgmt.FileAssetManager
import tapasco.jobs._
import tapasco.task._
import tapasco.util._

object Import extends Executor[ImportJob] {
  private[this] implicit val logger =
    tapasco.Logging.logger(getClass)

  def execute(job: ImportJob)
             (implicit cfg: Configuration, tsk: Tasks): Boolean = {
    if (!job.zipFile.toFile.exists) {
      throw new Exception("Missing .zip file, or file %s does not exist".format(job.zipFile))
    }
    val signal = new Semaphore(0)
    val jobs = for {
      a <- job.architectures
      p <- job.platforms
      t = Target(a, p)
    } yield (job, t)


    val tasks = jobs map { case (j, t) =>
      val avgCC = FileAssetManager.reports.cosimReport(VLNV.fromZip(j.zipFile).name, t) map (_.latency.avg)
      new ImportTask(j.zipFile, t, j.id, _ => signal.release(), avgCC, j.runEvaluation, j.synthOptions, j.optimization)(cfg)
    }

    tasks foreach {
      tsk.apply _
    }

    0 until tasks.size foreach { i =>
      signal.acquire()
      logger.debug("Import task #{} collected", i)
    }

    logger.info("all Import tasks have finished.")

    // success, if all tasks were successful
    (tasks map (_.result) fold true) (_ && _)
  }
}
