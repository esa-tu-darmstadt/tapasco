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
 * @file     CoreStatisticsTask.scala
 * @brief    Task to compute a spreadsheet of evaluation results of all
 *           available cores for a given [[Target]].
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.activity._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.Logging._

class CoreStatisticsTask(t: Target, fn: String, cfg: Configuration, val onComplete: Boolean => Unit)
    extends Task {
  private[this] final implicit val logger =
    de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  def description: String = "CoreStatistics for %s".format(t.toString)

  def job: Boolean = catchAllDefault(false, "core statistics for %s failed: ".format(t.toString)) {
    CoreStatistics(t, fn)(cfg)
  }

  // hardly any resource requirements: best guess 1 CPU, 256 MB memory, no licences
  val cpus = 1
  val memory = 256 * 1024
  val licences = Map()
}
