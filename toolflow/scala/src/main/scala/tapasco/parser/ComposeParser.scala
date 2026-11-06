/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
package tapasco.parser

import java.nio.file.Path

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
    (implementation | architectures | platforms | features | debugMode | skipSynth | effortLevel | delProj |
      extraPlugins | extraConstraints).rep
      .map(opts => (opts map (applyOption _) fold jobid) (_ andThen _))

  private val effortModes: Set[String] = Set("fastest", "fast", "normal",
    "optimal", "aggressive_performance", "aggressive_area")

  private def skipSynth: Parser[(String, Boolean)] =
    (longOption("skipSynthesis", "SkipSynthesis") ~ ws) map { case s => (s, true) }

  // unlike `path`, a list element stops at the list separators (quote a path that contains one of them)
  private def pluginPath: Parser[Path] =
    (quotedString | string("")).filter(p => tryToPath(p).nonEmpty).map(toPath _).opaque("plugin file or directory")

  private def extraPlugins: Parser[(String, Seq[Path])] =
    (longOption("extraPlugins", "ExtraPlugins") ~ ws ~/ seqOne(pluginPath) ~ ws)
      .opaque(s"list of plugin files or directories separated by one of $seqSepChars")

  private def extraConstraints: Parser[(String, Seq[Path])] =
    (longOption("extraConstraints", "ExtraConstraints") ~ ws ~/ seqOne(pluginPath) ~ ws)
      .opaque(s"list of XDC files or directories separated by one of $seqSepChars")

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
      } else {
        logger.warn(s"Unknown effort level $effort, using default normal")
        _.copy(effortLevel = Some("normal"))
      }
      case ("SkipSynthesis", s: Boolean) => _.copy(skipSynthesis = Some(s))
      case ("ExtraPlugins", ds: Seq[Path@unchecked]) => _.copy(extraPlugins = Some(ds))
      case ("ExtraConstraints", cs: Seq[Path@unchecked]) => _.copy(extraConstraints = Some(cs))
      case o => throw new Exception(s"parsed illegal option: $o")
    }
}
