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
import  scala.language.implicitConversions

sealed abstract class ManSection(private val n: Int, _manual: Option[String] = None) {
  require(n > 0 && n <= 9, "invalid section number, use 1-9")
  lazy val manual: String = _manual getOrElse "MAN(%d)".format(n)
}

// scalastyle:off magic.number
final case object GeneralCommands extends ManSection(1)
final case object SystemCalls extends ManSection(2)
final case object LibraryFunctions extends ManSection(3)
final case object SpecialFiles extends ManSection(4)
final case object FileFormatsConventions extends ManSection(5)
final case object GamesAndScreensavers extends ManSection(6)
final case object Miscellanea extends ManSection(7)
final case object SysAdminCommands extends ManSection(8)
// scalastyle:on magic.number

object ManSection {
  private lazy val numMap: Map[Int, ManSection] = all map (s => (s: Int) -> s) toMap

  lazy val all: Seq[ManSection] = Seq(
    GeneralCommands,
    SystemCalls,
    LibraryFunctions,
    SpecialFiles,
    FileFormatsConventions,
    GamesAndScreensavers,
    Miscellanea,
    SysAdminCommands
  )

  def apply(n: Int): ManSection = numMap(n)

  implicit def toManSection(n: Int): ManSection = apply(n)
  implicit def toInt(s: ManSection): Int        = s.n
}
