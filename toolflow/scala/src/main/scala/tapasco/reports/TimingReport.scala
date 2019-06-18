//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// // Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file     TimingReport.scala
 * @brief    Model for parsing and evaluating timing reports in Vivado format.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  java.nio.file.Path
import  scala.io.Source

/** Timing Report model. **/
final case class TimingReport(
    override val file: Path,
    worstNegativeSlack: Double,
    dataPathDelay: Double,
    maxDelayPath: TimingReport.TimingPath,
    minDelayPath: TimingReport.TimingPath,
    timingMet: Boolean) extends Report(file)

object TimingReport {
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)

  /** Model of a path in the design with slack value. */
  final case class TimingPath(source: String, destination: String, slack: Double)

  /** Produce TimingReport instance from file. **/
  def apply(sr: Path): Option[TimingReport] = extract(sr)

  // scalastyle:off magic.number
  /** Extracts the WNS line. **/
  private def wnsMatcher: SequenceMatcher[Double] = new SequenceMatcher(
      """^.*Design Timing Summary.*""".r,
      """^\s*WNS\(ns\)\s*TNS\(ns\).*""".r,
      """^\s*(-?\d+\.\d*).*""".r
    )(cons = ms => ms(2).group(1).toDouble)

  /** Extracts the maximal delay path. **/
  private def maxDelayPathMatcher: RepSeqMatcher[TimingPath] = new RepSeqMatcher(
      """^Max Delay Path.*""".r,
      """.*""".r,
      """^Slack[^:]*:\s*(-?\d+\.\d*).*""".r,
      """^\s*Source:\s*(?<source>\S+).*$""".r,
      """.*""".r,
      """^\s*Destination:\s*(\S+).*$""".r
    )(true, ms => TimingPath(ms(3).group("source"), ms(5).group(1), ms(2).group(1).toDouble))

  /** Extracts the minimal delay path. **/
  private def minDelayPathMatcher: RepSeqMatcher[TimingPath] = new RepSeqMatcher(
      """^Min Delay Path.*""".r,
      """.*""".r,
      """^Slack[^:]*:\s*(-?\d+\.\d*).*""".r,
      """^\s*Source:\s*(\S+).*$""".r,
      """.*""".r,
      """^\s*Destination:\s*(\S+).*$""".r
    )(true, ms => TimingPath(ms(3).group(1), ms(5).group(1), ms(2).group(1).toDouble))

  /** Extract the data delay path. */
  private def dataPathDelayMatcher: SequenceMatcher[Double] = new SequenceMatcher(
    """Data Path Delay:\s+([^ \t]+)ns""".r
  ) (true, ms => ms(0).group(1).toDouble)
  // scalastyle:on magic.number

  /** Extract min, max and average clock cycles from the timing report (if available). **/
  private def extract(sr: Path): Option[TimingReport] = try {
    val wns = wnsMatcher
    val dpd = dataPathDelayMatcher
    val max = maxDelayPathMatcher
    val min = minDelayPathMatcher
    Source.fromFile(sr.toString).getLines foreach { line =>
      wns.update(line)
      dpd.update(line)
      max.update(line)
      min.update(line)
    }
    if (wns.matched && dpd.matched && max.matched && min.matched) {
      Some(TimingReport(
        file = sr,
        worstNegativeSlack = wns.result.get,
        dataPathDelay = dpd.result.get,
        maxDelayPath = max.result.get.sortBy(_.slack).head,
        minDelayPath = min.result.get.sortBy(_.slack).last,
        timingMet = wns.result.get >= -0.3
      ))
    } else { None }
  } catch { case e: Exception =>
    logger.warn(Seq("Could not extract timing data from ", sr, ": ", e) mkString)
    None
  }
}
