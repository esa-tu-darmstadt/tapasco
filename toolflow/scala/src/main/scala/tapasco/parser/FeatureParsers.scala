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
import tapasco.base.Feature
import tapasco.base.Feature._

private object FeatureParsers {

  import BasicParsers._

  def feature: Parser[Feature] =
    (qstring.opaque("feature name").! ~ ws ~/
      featureBegin ~ ws ~/
      (featureKeyValue ~ ws).rep ~ ws ~/
      featureEnd ~ ws)
      .map(p => Feature(p._1, FMap(p._2.toMap)))

  def features: Parser[(String, Seq[Feature])] =
    longOption("features", "Features") ~ ws ~/ seqOne(feature)

  val featureBeginChars = "{(["
  val featureEndChars = "})]"
  val featureMarks = (featureBeginChars ++ featureEndChars) map (_.toString)
  val featureAssigns = Seq("->", "=", ":=", ":")

  def featureBegin: Parser[Unit] =
    CharIn(featureBeginChars).opaque(s"begin of feature mark, one of '$featureBeginChars'")

  def featureEnd: Parser[Unit] =
    CharIn(featureEndChars).opaque(s"end of feature mark, one of '$featureEndChars'")

  def featureAssign: Parser[Unit] = "->" | "=" | ":=" | ":"

  def featureKey: Parser[String] =
    (quotedString | string(featureAssigns ++ featureMarks))
      .opaque("feature key name")

  def featureVal: Parser[FString] =
    (quotedString | string(featureAssigns ++ featureMarks))
      .opaque("feature value for given key") map (a => FString(a))

  def featureKeyValue: Parser[(String, FString)] =
    featureKey ~ ws ~/
      featureAssign.opaque("feature assignment operator, one of '->', '=', ':=' or ':'") ~ ws ~/
      featureVal ~ ws
}
