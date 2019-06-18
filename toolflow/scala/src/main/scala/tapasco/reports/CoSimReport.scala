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
 * @file     CoSimReport.scala
 * @brief    Model for parsing and evaluating co-simulation reports in Vivado HLS format.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import  java.nio.file.Path
import  scala.io.Source

/** Co-Simulation Report model. **/
final case class CoSimReport(
    override val file: Path,
    latency: CoSimReport.ClockCycles,
    interval: CoSimReport.ClockCycles) extends Report(file) {
  require(Seq(latency.min, latency.avg, latency.max,
              interval.min, interval.avg, interval.max) map (_ != 1) reduce (_ || _),
          "at least one valid measure point must be found in report!")
}

object CoSimReport {
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)

  /** Model of the simulated clock cycles counts per execution (minimal, average and maximal). */
  final case class ClockCycles(min: Int, avg: Int, max: Int)

  object ClockCycles {
    private def parseOptionalInt(s: String): Int = try { s.toInt } catch { case e: NumberFormatException => 1 }
    def apply(min: String, avg: String, max: String): ClockCycles =
      ClockCycles(parseOptionalInt(min), parseOptionalInt(avg), parseOptionalInt(max))
  }

  /** Extract min, max and average clock cycles from the co-simulation report (if available). **/
  private def extractClockCycles(sr: Path): Option[(ClockCycles, ClockCycles)] = try {
      Source.fromFile(sr.toString)
            .getLines
            .map (_.split("\\|").map(_.trim))
            .filter (l => l.length > 2 && "Pass".equals(l(2)))
            // scalastyle:off magic.number
            .map (l => (ClockCycles(l(3), l(4), l(5)),
                        ClockCycles(l(6), l(7), l(8))))
            // scalastyle:on magic.number
            .toSeq.headOption
    } catch { case e: Exception => {
      logger.warn(Seq("Could not extract clock cycles from ", sr, ": ", e) mkString)
      None
    }}

  /** Produce CoSimReport instance from file. **/
  def apply(sr: Path): Option[CoSimReport] = {
    val cc = extractClockCycles(sr)
    if (cc.isEmpty) logger.warn(Seq("Failed to read co-sim report ", sr) mkString)
    cc map (c => CoSimReport(sr, c._1, c._2))
  }
}
