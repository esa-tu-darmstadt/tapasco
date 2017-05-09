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
 * @file     ImportTask.scala
 * @brief    Task to import an existing IP-XACT core to TPC. Performs
 *           out-of-context evaluation, if no report can be found.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.LogFileTracker
import  de.tu_darmstadt.cs.esa.tapasco.activity
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.util.VLNV
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  java.nio.file.Path

/**
 * The ImportTask is a schedulable job to import an existing IP-XACT core in a .zip
 * file into the cores library of current TPC configuration.
 * @param zip Path to the .zip file.
 * @param t Target to import core for.
 * @param id Id of the kernel this core implements.
 * @param averageClockCycles Clock cycle count in an average execution of the core (optional).
 * @param onComplete Callback function on completion of the task.
 * @param cfg TPC Configuration (implicit).
 **/
class ImportTask(val zip: Path, val t: Target, val id: Kernel.Id, val averageClockCycles: Option[Int],
    val onComplete: Boolean => Unit)(implicit val cfg: Configuration) extends Task with LogTracking {
  private implicit val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private val name = try { Some(VLNV.fromZip(zip).name) } catch { case _: Throwable => None }
  private lazy val _logFile = cfg.outputDir(name.get, t).resolve("%s.%s.import.log".format(
    zip.getFileName().toString, t.toString))

  def description: String = "Import of '%s' with target %s".format(zip.getFileName(), t)

  def job: Boolean = catchAllDefault(false, "import of %s for %s failed: ".format(zip, t)) {
    val appender = LogFileTracker.setupLogFileAppender(_logFile.toString)
    logger.trace("current thread name: {}", Thread.currentThread.getName())
    logger.info(description)
    logger.debug("debug: " + description)
    logger.trace("trace: " + description)
    val result = activity.Import(zip, id, t, averageClockCycles)
    LogFileTracker.stopLogFileAppender(appender)
    result
  }

  def logFiles: Set[String] = Set(_logFile.toString)

  // Resources for scheduling: one CPU per run, memory as per Xilinx website
  override val cpus = 1
  val memory = t.ad.name match {
    case "vc709"    => 7 * 1024 * 1024
    case "zc706"    => 5 * 1024 * 1024
    case "zedboard" => 2 * 1024 * 1024
    case "pynq"     => 2 * 1024 * 1024
    case _          => 7 * 1024 * 1024
  }
  val licences = Map(
    "Synthesis"             -> 1,
    "Implementation"        -> 1,
    "Vivado_System_Edition" -> 1
  )
}
