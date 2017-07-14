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
 * @file     SynthesisReport.scala
 * @brief    Model for parsing and evaluating synthesis reports in XML format
 *           (see common/ip_report.xml.template for an example).
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  java.nio.file.Path

/** Synthesis Report model. **/
final case class SynthesisReport(
    override val file: Path,
    area: Option[AreaEstimate],
    timing: Option[TimingEstimate]) extends Report(file) {
  require(file.toFile.exists, "file %s does not exist".format(file.toString))
  require(area.nonEmpty || timing.nonEmpty, "no synthesis results found in %s".format(file.toString))
}

object SynthesisReport {
  private[this] implicit val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)
  import de.tu_darmstadt.cs.esa.tapasco.Logging._

  /** Extracts the area estimation from the given synthesis report file.
    * @param sr Path to file
    * @return AreaEstimate if successful, None otherwise **/
  def extractArea(sr: Path): Option[AreaEstimate] = try {
      val xml = scala.xml.XML.loadFile(sr.toAbsolutePath.toString)
      (for (e <- List("Resources", "AvailableResources")) yield {
        val slice: Integer = ((xml \\ "AreaReport" \\ e \\ "SLICE") text).toInt
        val lut: Integer = ((xml \\ "AreaReport" \\ e \\ "LUT") text).toInt
        val ff: Integer = ((xml \\ "AreaReport" \\ e \\ "FF") text).toInt
        val dsp: Integer = ((xml \\ "AreaReport" \\ e \\ "DSP") text).toInt
        val bram: Integer = ((xml \\ "AreaReport" \\ e \\ "BRAM") text).toInt
        new ResourcesEstimate(slice, lut, ff, dsp, bram)
      }).grouped(2).map(x => new AreaEstimate(x.head, x.tail.head)).toList.headOption
    } catch { case e: Exception => logger.warn("parsing utilization report failed: " + e); None }

  /** Extracts the timing estimation from the given synthesis report file.
    * @param sr Path to file
    * @return TimingEstimate if successful, None otherwise **/
  def extractTiming(sr: Path): Option[TimingEstimate] = try {
      val xml = scala.xml.XML.loadFile(sr.toAbsolutePath.toString)
      Some(TimingEstimate(
        ((xml \\ "TimingReport" \\ "AchievedClockPeriod") text).toDouble,
        ((xml \\ "TimingReport" \\ "TargetClockPeriod") text).toDouble))
    } catch { case e: Exception => logger.warn("parsing timing report failed: " + e); None }

  /** Produce SynthesisReport instance from file. **/
  def apply(sr: Path): Option[SynthesisReport] = catchAllDefault(None: Option[SynthesisReport],
      "failed to read synthesis report %s: ".format(sr.toString)) {
    Some(SynthesisReport(sr, extractArea(sr), extractTiming(sr)))
  }
}
