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
package tapasco.activity.hls

import java.nio.file._

import tapasco.Logging._

import scala.io.Source

/** HighLevelSynthesizerLog is the abstract model for a HLS log file.
  * It uses simple pattern matching to identify errors and warnings
  * in text-based log file of a [[HighLevelSynthesizer]].
  *
  * @param file Path to log file.
  * */
final case class HighLevelSynthesizerLog(file: Path) {

  import HighLevelSynthesizerLog._

  private[this] final implicit val logger =
    tapasco.Logging.logger(getClass)
  private[this] final lazy val errMsg = "could not read HLS logfile %s: ".format(file.toString)

  /** All lines with errors in the log. */
  lazy val errors: Seq[String] = catchDefault(Seq[String](), Seq(classOf[java.io.IOException]), errMsg) {
    Source.fromFile(file.toString).getLines.filter(l => RE_ERROR.findFirstIn(l).nonEmpty).toSeq
  }

  /** All lines with warnings in the log. */
  lazy val warnings: Seq[String] = catchDefault(Seq[String](), Seq(classOf[java.io.IOException]), errMsg) {
    Source.fromFile(file.toString).getLines.filter(l => RE_WARN.findFirstIn(l).nonEmpty).toSeq
  }
}

/** Companion object for HighLevelSynthesizerLog.
  * Contains the regular expressions for matching.
  * */
private object HighLevelSynthesizerLog {
  private final val RE_ERROR = """(?i)error""".r.unanchored
  private final val RE_WARN = """(?i)warn""".r.unanchored
}
