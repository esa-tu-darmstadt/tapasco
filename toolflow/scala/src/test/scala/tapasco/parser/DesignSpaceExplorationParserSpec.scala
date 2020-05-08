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

class DesignSpaceExplorationParserSpec extends TaPaSCoSpec with Matchers with Checkers {

  import DesignSpaceExplorationParser._
  import DesignSpaceExplorationParserSpec._
  import org.scalacheck.Prop._

  implicit val cfg = PropertyCheckConfiguration(minSize = 50000, sizeRange = 1000)

  "All valid DSE jobs" should "be parsed correctly" in
    check(forAllNoShrink(dseGen) { d =>
      Common.checkParsed(P(dse ~ End).parse(d))
    })
}

private object DesignSpaceExplorationParserSpec {

  import BasicParserSpec._
  import CommonArgParsersSpec._
  import GlobalOptionsSpec.pathGen

  val dimensionGen: Gen[String] = Gen.oneOf(
    anyCase("area"),
    anyCase("utilization"),
    anyCase("util"),
    anyCase("freq"),
    anyCase("frequency"),
    anyCase("alts"),
    anyCase("alternatives")
  )

  val dimensionsGen: Gen[String] = for {
    n <- Gen.choose(1, 5)
    s <- join(0 until n map (_ => dimensionGen), sepStringGen)
  } yield s

  val heuristicGen: Gen[String] = join(Seq(
    genLongOption("heuristic"),
    Gen.oneOf(anyCase("throughput"), quoted(anyCase("job throughput")))
  ))

  val batchSizeGen: Gen[String] = join(Seq(
    genLongOption("batchSize"),
    Gen.posNum[Int] map (_.toString)
  ))

  val basePath: Gen[String] = join(Seq(
    genLongOption("basePath"),
    pathGen map (_.toString)
  ))

  val optionGen: Gen[String] = Gen.oneOf(
    heuristicGen,
    batchSizeGen,
    basePath,
    architecturesGen,
    platformsGen,
    debugModeGen,
    deleteProjectsGen
  )

  val optionsGen: Gen[String] = for {
    n <- Gen.choose(0, 10)
    o <- join(0 until n map (_ => optionGen))
  } yield o

  val dseGen: Gen[String] = join(Seq(
    anyCase("explore"),
    compositionGen,
    Gen.option(join(Seq("@", freqGen))) map (_ getOrElse ""),
    "in",
    dimensionsGen,
    optionsGen
  ))
}
