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

import java.nio.file.Path

import fastparse.all._
import tapasco.base._
import tapasco.dse._
import tapasco.jobs._

private object DesignSpaceExplorationParser {

  import BasicParsers._
  import CommonArgParsers._
  import FeatureParsers._

  def dse: Parser[DesignSpaceExplorationJob] = (
    IgnoreCase("explore") ~ ws ~/ composition ~/ ws ~
      ("@" ~ ws ~/ freq ~ ws1).? ~ ws ~
      IgnoreCase("in") ~ ws ~/ dimensions ~/ ws ~ options ~ ws
    ) map { case (_, comp, optfreq, dims, optf) => optf(DesignSpaceExplorationJob(
    initialComposition = comp,
    initialFrequency = optfreq,
    dimensions = dims,
    heuristic = Heuristics.ThroughputHeuristic,
    batchSize = None
  ))
  }

  private def optionsMap: Parser[Seq[(String, _)]] =
    (heuristic | batchSize | basePath | architectures | platforms | features | debugMode | delProj).rep

  private val jobid = identity[DesignSpaceExplorationJob] _

  private def options: Parser[DesignSpaceExplorationJob => DesignSpaceExplorationJob] =
    optionsMap map (opts => (opts map (applyOption _) fold jobid) (_ andThen _))

  private def heuristic: Parser[(String, String)] =
    longOption("heuristic", "Heuristic") ~ ws ~/ qstring.opaque("name of heuristic") ~ ws

  private def batchSize: Parser[(String, Int)] =
    longOption("batchSize", "BatchSize") ~ ws ~/ posint.opaque("batch size, positive integer > 0") ~ ws

  private def basePath: Parser[(String, Path)] =
    longOption("basePath", "BasePath") ~ ws ~/ path.opaque("base path") ~ ws

  private def applyOption(opt: (String, _)): DesignSpaceExplorationJob => DesignSpaceExplorationJob =
    opt match {
      case ("Architectures", as: Seq[String@unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", as: Seq[String@unchecked]) => _.copy(_platforms = Some(as))
      case ("Heuristic", h: String) => _.copy(heuristic = Heuristics(h))
      case ("BatchSize", i: Int) => _.copy(batchSize = Some(i))
      case ("BasePath", p: Path) => _.copy(basePath = Some(p))
      case ("Features", fs: Seq[Feature@unchecked]) => _.copy(features = Some(fs))
      case ("DebugMode", m: String) => _.copy(debugMode = Some(m))
      case ("DeleteProjects", e: Boolean) => _.copy(deleteProjects = Some(e))
      case o => throw new Exception(s"parsed illegal option: $o")
    }

  private def set(s: String): DesignSpace.Dimensions => DesignSpace.Dimensions =
    s.toLowerCase match {
      case "area" | "util" | "utilization" => _.copy(utilization = true)
      case "freq" | "frequency" => _.copy(frequency = true)
      case "alt" | "alts" | "alternatives" => _.copy(alternatives = true)
      case _ => throw new Exception(s"unknown design space dimension: '$s'")
    }

  private val dimid = identity[DesignSpace.Dimensions] _

  private def dimension = StringInIgnoreCase(
    "area", "util", "utilization",
    "freq", "frequency",
    "alt", "alts", "alternatives"
  ).!

  private def dimensions: Parser[DesignSpace.Dimensions] =
    seqOne(dimension) map { ss =>
      (((ss map (set _)) fold dimid) (_ andThen _)) (DesignSpace.Dimensions())
    }
}
