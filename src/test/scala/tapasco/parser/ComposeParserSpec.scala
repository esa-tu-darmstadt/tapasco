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
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class ComposeParserSpec extends FlatSpec with Matchers with Checkers {
  import ComposeParser._, ComposeParserSpec._
  import Prop._
  implicit val cfg = PropertyCheckConfiguration(minSize = 10000, sizeRange = 0)

  "All valid compose job specs" should "be parsed correctly by compose" in
    check(forAllNoShrink(composeGen) { cj =>
      Common.checkParsed( P( compose ~ End ).parse(cj) )
    })
}

private object ComposeParserSpec {
  /* @{ Generators and Arbitraries */
  val optionGen: Gen[String] = Gen.oneOf(
    CommonArgParsersSpec.implementationGen,
    CommonArgParsersSpec.architecturesGen,
    CommonArgParsersSpec.platformsGen,
    FeatureParsersSpec.featuresGen,
    CommonArgParsersSpec.debugModeGen
  )
  val optionsGen: Gen[String] = for {
    n <- Gen.choose(1, 20)
    p <- BasicParserSpec.join(0 until n map (_ => optionGen))
  } yield p.mkString

  val composeGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.anyCase("compose"),
    CommonArgParsersSpec.compositionGen,
    "@",
    CommonArgParsersSpec.freqGen,
    optionsGen
  ))
  /* Generators and Arbitraries @} */
}
