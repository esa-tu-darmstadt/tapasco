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
package tapasco.parser

import fastparse.all._
import tapasco.base._
import tapasco.jobs._

private object ComposeParser {

  import BasicParsers._
  import CommonArgParsers._
  import FeatureParsers._

  private final val logger = tapasco.Logging.logger(getClass)

  def compose: Parser[ComposeJob] =
    IgnoreCase("compose") ~ ws ~/ composition ~/ "@" ~ ws ~ freq ~/
      ws ~ options ~ ws map { case (_, c, f, optf) => optf(ComposeJob(
      composition = c,
      designFrequency = f,
      _implementation = "Vivado"
    ))
    }

  private val jobid = identity[ComposeJob] _

  private def options: Parser[ComposeJob => ComposeJob] =
    (implementation | architectures | platforms | features | debugMode | effortLevel | delProj).rep
      .map(opts => (opts map (applyOption _) fold jobid) (_ andThen _))

  private val effortModes: Set[String] = Set("fastest", "fast", "normal",
    "optimal", "aggressive_performance", "aggressive_area")

  private def applyOption(opt: (String, _)): ComposeJob => ComposeJob =
    opt match {
      case ("Implementation", i: String) => _.copy(_implementation = i)
      case ("Architectures", as: Seq[String@unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", ps: Seq[String@unchecked]) => _.copy(_platforms = Some(ps))
      case ("Features", fs: Seq[Feature@unchecked]) => _.copy(features = Some(fs))
      case ("DebugMode", m: String) => _.copy(debugMode = Some(m))
      case ("DeleteProjects", e: Boolean) => _.copy(deleteProjects = Some(e))
      case ("EffortLevel", effort: String) => if (effortModes.contains(effort.toLowerCase)) {
        _.copy(effortLevel = Some(effort))
      }
      else {
        logger.warn(s"Unknown effort level $effort, using default normal")
        _.copy(effortLevel = Some("normal"))
      }
      case o => throw new Exception(s"parsed illegal option: $o")
    }
}
