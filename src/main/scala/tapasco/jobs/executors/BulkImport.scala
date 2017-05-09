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
 * @file     BulkImport.scala
 * @brief    Task to bulk-import IP cores given in a comma-separated values file.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.jobs.executors
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  scala.util.Properties.{lineSeparator => NL}
import  scala.util.control.Exception._
import  scala.io.Source
import  java.nio.file.Paths
import  java.util.concurrent.Semaphore

private object BulkImport extends Executor[BulkImportJob] {
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private final val headerLine =
    Seq("Zip", "ID", "Description", "Architecture", "Platform", "Avg Runtime (clock cycles)")

  def execute(job: BulkImportJob)(implicit cfg: Configuration, tsk: Tasks): Boolean = {
    val csvFile = job.csvFile.toString
    if (! checkCsv(csvFile.toString)) {
      throw new Exception ("File '" + csvFile + "' is not in the expected format; use CSV with this header: " +
        NL + headerLine.mkString(", "))
    }

    val signal = new Semaphore(0)

    for (job <- readCsv(csvFile)) logger.trace("found job: {}", job)

    val importTasks = for {
      j <- readCsv(csvFile)
      a <- j.architectures
      p <- j.platforms
      t = Target(a, p)
    } yield new ImportTask(j.zipFile, t, j.id, j.averageClockCycles, _ => signal.release())(cfg)

    importTasks foreach { tsk.apply _ }

    0 until importTasks.length foreach { i =>
      signal.acquire()
      logger.debug("BulkImport task #{} collected", i)
    }

    logger.info("all BulkImport tasks have finished.")

    // success, if all tasks were successful
    (importTasks map (_.result) fold true) (_ && _)
  }

  private def checkCsv(fn: String): Boolean = (Source.fromFile(fn).getLines.take(1) map { line =>
    ((line.split("""\s*,\s*""") zip headerLine) map {
      case (c1, c2) => c1.toLowerCase.equals(c2.toLowerCase)
    } fold true) (_ && _)
  }).toSeq.headOption getOrElse false

  // scalastyle:off magic.number
  private def readCsv(fn: String)(implicit cfg: Configuration): Seq[ImportJob] = (for {
    line <- Source.fromFile(fn).getLines.drop(1)
    fields = line.split("""\s*,\s*""")
  } yield ImportJob(
      zipFile = Paths.get(fields(0)),
      id = fields(1).toInt,
      description = if (fields(2).length > 0) Some(fields(2)) else None,
      averageClockCycles = allCatch.opt(fields(5).toInt),
      _architectures = Some(Seq(fields(3))),
      _platforms = Some(Seq(fields(4))))).toSeq
  // scalastyle:on magic.number
}

