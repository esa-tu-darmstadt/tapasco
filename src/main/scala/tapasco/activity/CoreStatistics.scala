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
package de.tu_darmstadt.cs.esa.tapasco.activity
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.reports._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager
import  scala.util.Properties.{lineSeparator => NL}

/** CoreStatistics is an activity which collects Core data in a CSV file.
  * It is often helpful to be able to dump all out-of-context results
  * for all Cores into a CSV file for further analysis. This activity
  * simplifies the process of collecting data from multiple reports.
  **/
object CoreStatistics {
  /** Produce a CSV file containing the results.
    * @param target Architecture + Platform combination to dump for.
    * @param fileName Output filename of the CSV file.
    * @param cfg Implicit [[base.Configuration]].
    * @return true, iff successful
    **/
  def apply(target: Target, fileName: String)(implicit cfg: Configuration): Boolean =
    dumpCSV(target, fileName, FileAssetManager.reports.synthReports.toSeq filter { r =>
      FileAssetManager.targetForReport(r.file).equals(target)
    } map (path => CoreReports(
        path,
        PowerReport(path.file.resolveSibling("power.rpt")),
        TimingReport(path.file.resolveSibling("timing.rpt")))))

  private final case class CoreReports(
    synth: SynthesisReport,
    power: Option[PowerReport],
    timing: Option[TimingReport]
  )

  private def dumpCSV(target: Target, fileName: String, es: Seq[CoreReports]): Boolean = try {
    val fw = new java.io.FileWriter(fileName)
    fw.append(HEADER + NL)
    fw.append(es map { e => Seq(
      e.synth.file,
      dumpArea(e.synth),
      dumpClocks(e.synth),
      dumpPower(e.power),
      dumpAvgClockCycles(e.synth),
      dumpMaxDelayPath(e.timing)) mkString "," } mkString NL)
    fw.close()
    true
  } catch { case e: Exception => false }

  private def dumpArea(r: SynthesisReport): String =
    Seq(r.area.map(_.resources.SLICE), r.area.map("%2.1f" format _.slice),
        r.area.map(_.resources.LUT), r.area.map("%2.1f" format _.lut),
        r.area.map(_.resources.FF), r.area.map("%2.1f" format _.ff),
        r.area.map(_.resources.DSP), r.area.map("%2.1f" format _.dsp),
        r.area.map(_.resources.BRAM), r.area.map("%2.1f" format _.bram)
       ) map (_.getOrElse("N/A")) mkString ","

  private def dumpClocks(r: SynthesisReport): String =
    Seq(r.timing.map(_.clockPeriod).getOrElse(""),
        r.timing.map(_.targetPeriod).getOrElse("")
       ) mkString ","

  private def dumpPower(pr: Option[PowerReport]): String = pr match {
    case Some(r) => Seq(r.totalOnChipPower.getOrElse(""),
                        r.dynamicPower.getOrElse(""),
                        r.staticPower.getOrElse(""),
                        r.confidenceLevel.getOrElse("")) mkString ","
    case _ => Seq("","","","") mkString ","
  }

  private def dumpAvgClockCycles(r: SynthesisReport): String =
    Core.from(r.file.getParent.resolveSibling("core.json")) map { cd =>
        Seq(cd.averageClockCycles.getOrElse(""),
            (for (t <- r.timing; c <- cd.averageClockCycles)
              yield "%2.2f" format (1.0 / ((t.clockPeriod * c) / 1000000000.0f))).getOrElse("")
           ) mkString ","
      } getOrElse ""

  private def dumpMaxDelayPath(r: Option[TimingReport]): String =
    Seq(r.map(_.maxDelayPath.slack),
        r.map(_.maxDelayPath.source),
        r.map(_.maxDelayPath.destination)
       ) map (_ getOrElse "") mkString ","

  private final val HEADER = Seq(
      "Core", "Slices", "Slices (%)", "LUT", "LUT (%)", "FF", "FF (%)",
      "DSP", "DSP (%)", "BRAM", "BRAM (%)", "AchievedClockPeriod", "TargetClockPeriod",
      "Total On-Chip Power (W)", "Dynamic Power (W)", "Device Static Power (W)", "Power Confidence Level",
      "Average Runtime (clock cycles)", "Jobs / s",
      "Max Delay Path Slack", "Max Delay Path Source", "Max Delay Path Destination"
    ) mkString ","
}
