//
// Copyright (C) 2016 Jens Korinth, TU Darmstadt
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
 * @file     ComposerLog.scala
 * @brief    Model for Composer tool logfiles.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.activity.composers
import java.nio.file.Path
import scala.io.Source

/** ComposerLog is an abstract definition of a log file produced by a Composer.
  * It uses simple pattern matching to identify errors and warnings in text
  * based log files.
  **/
class ComposerLog(val file: Path) {
  import ComposerLog._
  import ComposeResult._
  /** Returns all lines containing error messages in log. **/
  val errors   = Source.fromFile(file.toString).getLines.zipWithIndex.filter(
      _ match { case (line, idx) => ! RE_ERROR.findFirstIn(line).isEmpty }).toSeq
  /** Returns all lines containign error messages in log. **/
  val warnings = Source.fromFile(file.toString).getLines.zipWithIndex.filter(
      _ match { case (line, idx) => ! RE_WARNING.findFirstIn(line).isEmpty }).toSeq
  /** Interprets the warnings and errors to generate a result value. */
  def result: ComposeResult = if (errors.isEmpty) {
    if ((warnings map (line => RE_TIMING.findFirstIn(line._1).isEmpty) fold true) (_ && _)) {
      Success
    } else {
      TimingFailure
    }
  } else {
    if ((errors map (line => RE_PLACER.findFirstIn(line._1).isEmpty) fold true) (_&&_)) {
      OtherError
    } else {
      PlacerError
    }
  }
}

/** Companion object for ComposerLog.
  * Contains the regular expressions and a convenience constructor.
  **/
object ComposerLog {
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)
  def apply(file: Path): Option[ComposerLog] = try { Some(new ComposerLog(file)) } catch { case e: Exception =>
      logger.warn("could not read logfile " + file + ": " + e); None }

  private val RE_ERROR   = """(?i)^[^_]*error""".r
  private val RE_WARNING = """(?i)warn""".r
  private val RE_PLACER = """(?i)(Placer could not place all instances)|(ERROR:\s*\[Place)""".r
  private val RE_TIMING = """Timing 38-282""".r
}

