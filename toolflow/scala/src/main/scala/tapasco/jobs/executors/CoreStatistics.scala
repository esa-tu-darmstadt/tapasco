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
 * @file     CoreStatistics.scala
 * @brief    Command to scan the cores directory and produce spreadsheets for each
 *           platform and architecture containing the evaluation results of all
 *           currently available cores.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.jobs.executors
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  java.util.concurrent.Semaphore

private object CoreStatistics extends Executor[CoreStatisticsJob] {
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  def execute(job: CoreStatisticsJob)(implicit cfg: Configuration, tsk: Tasks): Boolean = {
    val signal = new Semaphore(0)

    val tasks: Set[CoreStatisticsTask] = for {
      pd <- job.platforms
      ad <- job.architectures
      t = Target(ad, pd)
    } yield new CoreStatisticsTask(t, "%s%s.csv".format(job.prefix getOrElse "", t.toString), cfg, _ => signal.release())

    logger.info("launching {} CoreStatistics tasks ...", tasks.size)

    tasks.foreach { tsk.apply _ }

    0 until tasks.size foreach { i =>
      signal.acquire()
      logger.debug("CoreStatistics task #{} collected", i)
    }

    logger.info("all tasks finished")

    // successfull, iff all successful
    (tasks map (_.result) fold true) (_ && _)
  }
}
