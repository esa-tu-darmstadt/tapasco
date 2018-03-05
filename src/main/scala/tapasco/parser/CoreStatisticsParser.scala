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
package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._

private object CoreStatisticsParser {
  import BasicParsers._
  import CommonArgParsers._

  def corestats: Parser[CoreStatisticsJob] =
    IgnoreCase("corestats") ~/ (ws1 ~ options).? ~ ws map (_.map(_.apply(CoreStatisticsJob())) getOrElse CoreStatisticsJob())

  private val jobid = identity[CoreStatisticsJob] _

  private def prefix: Parser[(String, String)] =
    longOption("prefix", "Prefix") ~ ws ~/ qstring.opaque("prefix string") ~ ws

  private def options: Parser[CoreStatisticsJob => CoreStatisticsJob] =
    (prefix | architectures | platforms).rep map (opts =>
      (opts map (applyOption _) fold jobid) (_ andThen _))

  private def applyOption(opt: (String, _)): CoreStatisticsJob => CoreStatisticsJob =
    opt match {
      case ("Prefix", prefix: String) => _.copy(prefix = Some(prefix))
      case ("Architectures", as: Seq[String @unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", ps: Seq[String @unchecked]) => _.copy(_platforms = Some(ps))
      case o => throw new Exception(s"parsed illegal option: $o")
    }
}
