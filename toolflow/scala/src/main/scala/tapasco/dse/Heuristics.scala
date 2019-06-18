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
 * @file     Heuristics.scala
 * @brief    Heuristic functions for the automated design space exploration.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.dse
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager
import  de.tu_darmstadt.cs.esa.tapasco.base._

object Heuristics {
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)
  type Frequency = Double
  type Value     = Double
  abstract class Heuristic extends Function3[Composition, Frequency, Target, Configuration => Value]

  def apply(name: String): Heuristic = name.toLowerCase match {
    case "throughput" | "job throughput" => ThroughputHeuristic
    case o => throw new Exception(s"unknown heuristic: '$o'")
  }

  object ThroughputHeuristic extends Heuristic {
    private def findAverageClockCycles(kernel: String, target: Target)
                (implicit cfg: Configuration): Int = {
      val cd = FileAssetManager.entities.core(kernel, target) getOrElse {
        throw new Exception("could not find core description for %s @ %s".format(kernel, target))
      }
      cd.averageClockCycles.getOrElse {
        val report = FileAssetManager.reports.cosimReport(kernel, target)
        if (report.isEmpty) {
          logger.warn("Core description does not contain 'averageClockCycles' and " +
              "co-simulation report could not be found, assuming one-cycle execution: " +
              kernel + " [" + cd.descPath + "]")
        }
        report map (_.latency.avg) getOrElse (1)
      }
    }

    def apply(bd: Composition, freq: Frequency, target: Target): Configuration => Value = cfg => {
      val maxClockCycles: Seq[Int] = bd.composition map (ce => findAverageClockCycles(ce.kernel, target)(cfg))
      val t = 1.0 / (freq * 1000000.0)
      val t_irq = target.pd.benchmark map (_.latency(maxClockCycles.max) / 1000000000.0) getOrElse 0.0
      val jobsla = maxClockCycles map (_ * t + t_irq/* + t_setup*/)
      bd.composition map (_.count) zip jobsla map (x => x._1 / x._2) reduce (_ + _)
    }
  }
}
