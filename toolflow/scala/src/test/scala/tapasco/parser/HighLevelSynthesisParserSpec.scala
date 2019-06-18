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
class HighLevelSynthesisParserSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import HighLevelSynthesisParser._, HighLevelSynthesisParserSpec._, Common._
  implicit val cfg = PropertyCheckConfiguration(minSize = 100000)

  "All valid HLS jobs" should "be correctly parsed by hls" in
    check(forAll(hlsGen) { h =>
      checkParsed(P( hls ~ End ).parse(h))
    })
}

private object HighLevelSynthesisParserSpec {
  import BasicParserSpec._, CommonArgParsersSpec._

  val implementationGen: Gen[String] = join(Seq(
    genLongOption("implementation"),
    Gen.oneOf(anyCase("VivadoHLS"), quoted(anyCase("VivadoHLS")))
  ))

  val kernelGen: Gen[String] = for {
    g <- qstringGen
  } yield g.replaceAll("all", "asdf")

  val allGen: Gen[String]    = anyCase("all")

  val optionGen: Gen[String] = Gen.oneOf(
    platformsGen,
    architecturesGen,
    implementationGen
  )

  val optionsGen: Gen[String] = for {
    n <- Gen.choose(0, 10)
    s <- join(0 until n map (_ => optionGen))
  } yield s

  val hlsGen: Gen[String] = join(Seq(
    anyCase("hls"),
    Gen.oneOf(allGen, seqOne(kernelGen, sepStringGen)),
    optionsGen
  ))
}
