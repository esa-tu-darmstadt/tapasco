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

class CommonArgParsersSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import CommonArgParsers._, CommonArgParsersSpec._, Common._
  implicit val cfg = PropertyCheckConfiguration(minSize = 1000, sizeRange = 100)

  "All valid --architectures options" should "be parsed correctly by architectures" in
    check(forAll(architecturesGen) { ap =>
      checkParsed( P( architectures ~ End ).parse(ap) )
    })

  "All valid --platform options" should "be parsed correctly by platforms" in
    check(forAll(platformsGen) { ap =>
      checkParsed( P( platforms ~ End ).parse(ap) )
    })

  "All valid composition entries" should "be parsed correctly by compositionEntry" in
    check(forAllNoShrink(compositionEntryGen) { e =>
      checkParsed( P( compositionEntry ~ End ).parse(e) )
    })

  "All valid compositions" should "be parsed correctly by composition" in
    check(forAllNoShrink(compositionGen) { c =>
      checkParsed ( P( composition ~ End ).parse(c) )
    })

  "All valid frequency strings" should "be parsed correctly by freq" in
    check(forAllNoShrink(Gen.posNum[Double]) { f =>
      checkParsed( P( freq ~ End ).parse("%1.12f".format(f)) )
    })

  "All valid debugMode parameters" should "be parsed correctly by debugMode" in
    check(forAllNoShrink(debugModeGen) { d =>
      checkParsed( P( debugMode ~ End ).parse(d) )
    })

  "The deleteProject switch" should "be parsed correctly by deleteProject" in
    check(forAllNoShrink(deleteProjectsGen) { d =>
      checkParsed(P(delProj ~ End).parse(d))
    })

  "All valid synthEffort parameters" should "be parsed correctly by synthEffort" in
    check(forAllNoShrink(effortModeGen) { e =>
      checkParsed( P(synthEffort ~ End).parse(e))
    })

  "All valid implementation parameters" should "be parsed correctly by implementation" in
    check(forAllNoShrink(implementationGen) { i =>
      checkParsed( P( implementation ~ End ).parse(i) )
    })
}

private object CommonArgParsersSpec {
  import BasicParserSpec._

  /* {@ Generators and Arbitraries */
  val architecturesSeqGen = seqOne(qstringGen, sepStringGen)
  val architecturesGen: Gen[String] = join(Seq(
    genLongShortOption("architectures", "a"),
    architecturesSeqGen
  ))

  val platformsSeqGen = seqOne(qstringGen, sepStringGen)
  val platformsGen: Gen[String] = join(Seq(
    genLongShortOption("platforms", "p"),
    platformsSeqGen
  ))

  val compositionEntryGen: Gen[String] = join(Seq(
    qstringGen,
    "x",
    Gen.chooseNum(1, 128) map (_.toString)
  ))

  val compositionGen: Gen[String] = for {
    n   <- Gen.choose(1, 10)
    fs  <- join(0 until n map (_ => compositionEntryGen), sepStringGen)
    ws1 <- wsStringGen
    ws2 <- wsStringGen
  } yield s"[$ws1$fs$ws2]"

  val freqGen: Gen[String] = join(Seq(
    Gen.posNum[Double] map (d => "%1.12f".format(d)),
    wsStringGen,
    Gen.option(anyCase("MHz")) map (_ getOrElse "")
  ))

  val debugModeGen: Gen[String] = join(Seq(
    genLongOption("debugMode"),
    qstringGen
  ))

<<<<<<< HEAD
  val booleanOrNoneGen: Gen[String] = Gen.oneOf("true", "false", "")

  val deleteProjectsGen: Gen[String] = join(Seq(genLongOption("deleteProjects"), booleanOrNoneGen))
=======
  val effortModeGen : Gen[String] = join(Seq(
    genLongOption("synthEffort"),
    Gen.oneOf("fastest", "fast", "normal", "optimal", "optimal", "aggressive_performance", "aggressive_area")
  ))
>>>>>>> Introduce additional flag for compose command, setting the effort level;

  val implementationGen: Gen[String] = join(Seq(
    genLongOption("implementation"),
    qstringGen
  ))
  /* Generators and Arbitraries @} */
}
