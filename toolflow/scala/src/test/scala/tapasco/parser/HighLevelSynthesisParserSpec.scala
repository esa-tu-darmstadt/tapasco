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

import fastparse.all._
import org.scalacheck._
import org.scalatest._
import org.scalatest.prop.Checkers
import tapasco.TaPaSCoSpec

class HighLevelSynthesisParserSpec extends TaPaSCoSpec with Matchers with Checkers {

  import Common._
  import HighLevelSynthesisParser._
  import HighLevelSynthesisParserSpec._
  import org.scalacheck.Prop._

  implicit val cfg = PropertyCheckConfiguration(minSize = 100000)

  "All valid HLS jobs" should "be correctly parsed by hls" in
    check(forAll(hlsGen) { h =>
      checkParsed(P(hls ~ End).parse(h))
    })
}

private object HighLevelSynthesisParserSpec {

  import BasicParserSpec._
  import CommonArgParsersSpec._

  val implementationGen: Gen[String] = join(Seq(
    genLongOption("implementation"),
    Gen.oneOf(anyCase("VivadoHLS"), quoted(anyCase("VivadoHLS")))
  ))

  val kernelGen: Gen[String] = for {
    g <- qstringGen
  } yield g.replaceAll("all", "asdf")

  val allGen: Gen[String] = anyCase("all")

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
