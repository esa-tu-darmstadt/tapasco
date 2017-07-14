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
 * @file     PowerReport.scala
 * @brief    Model for parsing and evaluating power reports in Vivado format.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import  java.nio.file.Path
import  scala.io.Source

/** Co-Simulation Report model. **/
final case class PowerReport(
    override val file: Path,
    totalOnChipPower: Option[Double],
    dynamicPower: Option[Double],
    staticPower: Option[Double],
    confidenceLevel: Option[String]) extends Report(file) {
  require( Seq(totalOnChipPower, dynamicPower, staticPower, confidenceLevel) map (_.nonEmpty) reduce (_ || _),
      "need at least one valid measurement in power report")
}

object PowerReport {
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)
  private final val STR_TOCP = "Total On-Chip Power (W)"
  private final val STR_DYNP = "Dynamic (W)"
  private final val STR_STAP = "Device Static (W)"
  private final val STR_CONF = "Confidence Level"
  private final val STR_FILTERS = Seq(STR_TOCP, STR_DYNP, STR_STAP, STR_CONF)

  /** Produce PowerReport instance from file. **/
  def apply(sr: Path): Option[PowerReport] = try {
      val matches =
          Source.fromFile(sr.toString)
            .getLines
            .map (_.split("\\|") map (_.trim))
            .filter (l => l.length > 2 && STR_FILTERS.contains(l(1)))
            .map (l => (l(1), l(2)))
      Some(PowerReport(sr,
        (matches filter (l => l._1.equals(STR_TOCP)) toSeq).headOption map(_._2.toDouble),
        (matches filter (l => l._1.equals(STR_DYNP)) toSeq).headOption map(_._2.toDouble),
        (matches filter (l => l._1.equals(STR_STAP)) toSeq).headOption map(_._2.toDouble),
        (matches filter (l => l._1.equals(STR_CONF)) toSeq).headOption map(_._2)
      ))
    } catch { case e: Exception => {
      logger.warn(Seq("Could not extract power data from ", sr, ": ", e) mkString)
      None
    }}
}
