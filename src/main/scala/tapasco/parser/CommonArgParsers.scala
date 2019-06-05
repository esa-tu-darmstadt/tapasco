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
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.dse.Heuristics
import  fastparse.all._
import  java.nio.file._

private object CommonArgParsers {
  import BasicParsers._

  def architectures: Parser[(String, Seq[String])] =
    (longShortOption("a", "architectures", Some("Architectures")) ~ ws ~/ seqOne(qstring) ~ ws)
      .opaque(s"list of architecture names separated by one of $seqSepChars")

  def platforms: Parser[(String, Seq[String])] =
    (longShortOption("p", "platforms", Some("Platforms")) ~ ws ~/ seqOne(qstring) ~ ws)
      .opaque(s"list of platform names separated by one of $seqSepChars")

  def kernel: Parser[String] = qstring.opaque("kernel name")

  def compositionEntry: Parser[Composition.Entry] =
    (kernel.! ~ ws1 ~ "x" ~ ws ~ posint)
      .opaque("composition entry of form <KERNEL NAME> 'x' <COUNT>")
      .map (p => Composition.Entry(p._1, p._2))

  def compositionSeq: Parser[Seq[Composition.Entry]] =
    (BasicParsers.seqOne(compositionEntry) ~ ws)
      .opaque("list of composition entries of form <KERNEL NAME> 'x' <COUNT>")

  def compositionBegin: Parser[Unit] = "[" ~ ws opaque("start of composition: '['")
  def compositionEnd: Parser[Unit]   = "]" ~ ws opaque("end of composition: ']'")

  def compositionFile: Parser[Composition] =
    path.opaque("path to composition Json file") map loadCompositionFromFile _

  def compositionSpec: Parser[Composition] =
    (compositionBegin ~/ compositionSeq ~ compositionEnd)
      .map (c => Composition(Paths.get(""), None, composition = c))

  def composition: Parser[(String, Composition)] =
    compositionSpec | compositionFile map (("Composition", _))

  def freq: Parser[Heuristics.Frequency] =
    (frequency ~/ (ws ~ IgnoreCase("MHz")).? ~ &(ws))
      .filter(_ > 0.0)
      .opaque("positive floating point value for frequency in MHz")

  def debugMode: Parser[(String, String)] =
    longOption("debugMode", "DebugMode") ~ ws ~/
    qstring.opaque("debug mode name, any string") ~ ws

  def delProj: Parser[(String, Boolean)] =
    (longOption("deleteProjects", "DeleteProjects") ~ ws) map {case s => (s, true)}

  def implementation: Parser[(String, String)] =
    longOption("implementation", "Implementation") ~
    ws ~/
    qstring.opaque("implementation name, any string") ~/
    ws

  private def loadCompositionFromFile(p: Path): Composition = Composition.from(p) match {
    case Right(c) => c
    case Left(e)  => throw e
  }
}
