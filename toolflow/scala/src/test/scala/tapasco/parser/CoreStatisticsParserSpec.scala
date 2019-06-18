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
import org.scalacheck._
import org.scalatest._
import org.scalatest.prop.Checkers
import fastparse.all._
import org.junit.runner.RunWith
import org.scalatest.junit.JUnitRunner

@RunWith(classOf[JUnitRunner])
class CoreStatisticsParserSpec extends FlatSpec with Matchers with Checkers {
  import CoreStatisticsParser._, CoreStatisticsParserSpec._
  import Prop._
  import Common._
  implicit val cfg = PropertyCheckConfiguration(minSize = 10000)

  "All valid CoreStat jobs" should "be parsed correctly" in
    check(forAllNoShrink(corestatsGen) { j =>
      checkParsed(P( corestats ~ End ).parse(j))
    })
}

private object CoreStatisticsParserSpec {
  val prefixGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.genLongOption("prefix"),
    BasicParserSpec.qstringGen
  ))

  val optionGen: Gen[String] = Gen.oneOf(
    prefixGen,
    CommonArgParsersSpec.platformsGen,
    CommonArgParsersSpec.architecturesGen
  )

  val optionsGen: Gen[String] = Gen.choose(0, 20) flatMap { n =>
    BasicParserSpec.join(0 until n map (_ => optionGen))
  }

  val corestatsGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.anyCase("corestats"),
    optionsGen
  ))
}
