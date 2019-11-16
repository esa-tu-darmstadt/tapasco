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
package tapasco.jobs.executors

import java.util.concurrent.Semaphore

import tapasco.Logging
import tapasco.activity.hls.HighLevelSynthesizer
import tapasco.activity.hls.HighLevelSynthesizer.Implementation._
import tapasco.activity.hls.HighLevelSynthesizer._
import tapasco.base._
import tapasco.filemgmt.FileAssetManager
import tapasco.jobs._
import tapasco.task._

protected object HighLevelSynthesis extends Executor[HighLevelSynthesisJob] {
  private implicit final val logger = Logging.logger(getClass)

  def execute(job: HighLevelSynthesisJob)(implicit cfg: Configuration, tsk: Tasks): Boolean = {
    val signal = new Semaphore(0)
    val runs: Seq[(Kernel, Target)] = for {
      a <- job.architectures.toSeq.sortBy(_.name)
      p <- job.platforms.toSeq.sortBy(_.name)
      k <- job.kernels.toSeq.sortBy(_.name)
      t = Target(a, p)
    } yield (k, t)

    val tasks = for {
      (k, t) <- runs
    } yield new HighLevelSynthesisTask(k, t, cfg, VivadoHLS, _ => signal.release())

    tasks foreach {
      tsk.apply _
    }

    0 until tasks.length foreach { i =>
      signal.acquire()
      logger.debug("HLS task #{} collected", i)
    }

    logger.info("all HLS tasks have finished.")

    val results: Seq[((Kernel, Target), Option[HighLevelSynthesizer.Result])] =
      (runs zip (tasks map (_.synthesisResult))) filter {
        case (_, Some(Success(_, _))) => true
        case _ => false
      }

    logger.trace("results: {}", results)

    val importTasks = results flatMap {
      case ((k, t), Some(Success(_, zip))) => {
        logger.trace("searching for co-simulation report for {} @ {}", k.name: Any, t)
        val rpt = FileAssetManager.reports.cosimReport(k.name, t)
        logger.trace("co-simulation report: {}", rpt)
        val avgCC = rpt map (_.latency.avg)
        logger.trace("average clock cycles: {}", avgCC)
        if (avgCC.isEmpty && k.testbenchFiles.length > 0) {
          logger.warn("executed HLS with co-sim for {}, but no co-simulation report was found", k.name)
        }
        Some(new ImportTask(zip, t, k.id, _ => signal.release(), avgCC, job.skipEvaluation, None, 2)(cfg))
      }
      case _ => None
    }

    importTasks foreach {
      tsk.apply _
    }

    0 until importTasks.length foreach { i =>
      signal.acquire()
      logger.debug("Import task #{} collected", i)
    }

    // success, if all tasks were successful
    ((tasks ++ importTasks) map (_.result) fold false) (_ || _)
  }
}
