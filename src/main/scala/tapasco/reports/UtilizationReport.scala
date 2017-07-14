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
 * @file     UtilizationReport.scala
 * @brief    Model for parsing and evaluating utilization reports in Vivado format.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  scala.util.matching._
import  scala.io.Source
import  java.nio.file._

final case class UtilizationReport(
    override val file: Path,
    used: ResourcesEstimate,
    available: ResourcesEstimate) extends Report(file) {
}

object UtilizationReport {
  private implicit final val logger =
    de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private final val LUTS_REGEX   =
    new Regex("""\| Slice LUTs\s+\|\s+(\d+)\s+\|\s+\d+\s+\|\s+(\d+)""", "used", "available")
  private final val FF_REGEX     =
    new Regex("""\| Slice Registers\s+\|\s+(\d+)\s+\|\s+\d+\s+\|\s+(\d+)""", "used", "available")
  private final val SLICE_REGEX  =
    new Regex("""\| Slice\s+\|\s+(\d+)\s+\|\s+\d+\s+\|\s+(\d+)""", "used", "available")
  private final val DSP_REGEX    =
    new Regex("""\| DSPs\s+\|\s+(\d+)\s+\|\s+\d+\s+\|\s+(\d+)""", "used", "available")
  private final val BRAM_REGEX   =
    new Regex("""\| Block RAM Tile\s+\|\s+([^ \t]+)\s+\|\s+\d+\s+\|\s+(\d+)""", "used", "available")
  private final val MISSING = "could not parse value for %s in %s"

  final val InvalidValue = -1

  def apply(reportFile: Path): Option[UtilizationReport] = catchDefault(None: Option[UtilizationReport],
      Seq(classOf[java.io.IOException]), "could not read file %s: ".format(reportFile.toString)) {
    val rpt = Source.fromFile(reportFile.toString) mkString ""

    val slice = SLICE_REGEX.findFirstMatchIn(rpt) map (m => (m.group(1).toInt, m.group(2).toInt))
    if (slice.isEmpty) logger.warn(MISSING.format("slices", reportFile.toString))
    val (slice_u, slice_a) = slice.getOrElse (InvalidValue, InvalidValue)

    val luts = LUTS_REGEX.findFirstMatchIn(rpt) map (m => (m.group(1).toInt, m.group(2).toInt))
    if (luts.isEmpty) logger.warn(MISSING.format("luts", reportFile.toString))
    val (luts_u, luts_a) = luts.getOrElse (InvalidValue, InvalidValue)

    val ff = FF_REGEX.findFirstMatchIn(rpt) map (m => (m.group(1).toInt, m.group(2).toInt))
    if (ff.isEmpty) logger.warn(MISSING.format("ff", reportFile.toString))
    val (ff_u, ff_a) = ff.getOrElse (InvalidValue, InvalidValue)

    val dsp = DSP_REGEX.findFirstMatchIn(rpt) map (m => (m.group(1).toInt, m.group(2).toInt))
    if (dsp.isEmpty) logger.warn(MISSING.format("dsp", reportFile.toString))
    val (dsp_u, dsp_a) = dsp.getOrElse (InvalidValue, InvalidValue)

    def mkint(ds: String): Int = math.ceil(ds.toDouble).toInt
    val bram = BRAM_REGEX.findFirstMatchIn(rpt) map (m => (mkint(m.group(1)), mkint(m.group(2))))
    if (bram.isEmpty) logger.warn(MISSING.format("bram", reportFile.toString))
    val (bram_u, bram_a) = bram.getOrElse (InvalidValue, InvalidValue)

    if (Seq(slice, luts, ff, dsp, bram) map (_.nonEmpty) reduce (_ || _)) {
      Some(UtilizationReport(
        reportFile,
        ResourcesEstimate(SLICE = slice_u, LUT = luts_u, FF = ff_u, DSP = dsp_u, BRAM = bram_u),
        ResourcesEstimate(SLICE = slice_a, LUT = luts_a, FF = ff_a, DSP = dsp_a, BRAM = bram_a)
      ))
    } else {
      None
    }
  }
}
