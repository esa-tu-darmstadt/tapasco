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
import tapasco.jobs._

private object ImportParser {

  import BasicParsers._
  import CommonArgParsers._

  def importzip: Parser[ImportJob] =
    (IgnoreCase("import") ~ ws ~/ zip ~ ws1 ~ IgnoreCase("as") ~ ws ~/ id ~ ws ~/ options ~ ws)
      .map { case (zip, id, optf) => optf(ImportJob(zipFile = zip, id = id)) }

  private def id: Parser[Kernel.Id] = posint.opaque("TaPaSCo function id, integer > 0")

  private def zip: Parser[Path] = path.opaque("path to .zip file containing IP-XACT core")

  private val jobid = identity[ImportJob] _

  private def options: Parser[ImportJob => ImportJob] =
    (description | avgClockCycles | skipEval | architectures | platforms | synthOptions | optimization).rep map (opts =>
      (opts map (applyOption _) fold jobid) (_ andThen _))

  private def description: Parser[(String, String)] =
    longOption("description", "Description") ~ ws ~/ qstring.opaque("description text as string") ~ ws

  private def avgClockCycles: Parser[(String, Int)] =
    longOption("averageClockCycles", "AvgCC") ~ ws ~/
      posint.opaque("avg. number of clock cycles, integer > 0") ~ ws

  private def skipEval: Parser[(String, Boolean)] =
    (longOption("skipEvaluation", "SkipEval") ~ ws) map { case s => (s, true) }

  private def synthOptions: Parser[(String, String)] =
    longOption("synthOptions", "SynthOptions") ~ ws ~/ qstring.opaque("additional synth_design options as string") ~ ws

  private def optimization: Parser[(String, Int)] =
    longOption("optimization", "Optimization") ~ ws ~/ posint.opaque("positive integer optimization level") ~ ws

  private def applyOption(opt: (String, _)): ImportJob => ImportJob = opt match {
    case ("Description", d: String) => _.copy(description = Some(d))
    case ("AvgCC", cc: Int) => _.copy(averageClockCycles = Some(cc))
    case ("SkipEval", se: Boolean) => _.copy(skipEvaluation = Some(se))
    case ("SynthOptions", so: String) => _.copy(synthOptions = Some(so))
    case ("Architectures", as: Seq[String@unchecked]) => _.copy(_architectures = Some(as))
    case ("Platforms", ps: Seq[String@unchecked]) => _.copy(_platforms = Some(ps))
    case ("Optimization", lvl: Int) => _.copy(_optimization = Some(lvl))
    case o => throw new Exception(s"parsed illegal option: $o")
  }
}
