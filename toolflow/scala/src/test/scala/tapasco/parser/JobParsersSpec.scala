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
import org.scalacheck._
import org.scalatest._
import org.scalatest.prop.Checkers
import tapasco.TaPaSCoSpec

class JobParsersSpec extends TaPaSCoSpec with Matchers with Checkers {
  import Common._
  import JobParsers._
  import JobParsersSpec._
  import org.scalacheck.Prop._

  "All valid jobs" should "be correctly parsed by job" in
    check(forAllNoShrink(jobGen) { h =>
      checkParsed(P( job ~ End ).parse(h))
    })
  "All sequences of valid jobs" should "be correctly parsed by jobs" in
    check(forAllNoShrink(jobsGen) { h =>
      checkParsed(P( jobs ~ End ).parse(h))
    })
}

private object JobParsersSpec {
  val jobGen: Gen[String] = Gen.oneOf(
    BulkImportParserSpec.bulkImportGen,
    ComposeParserSpec.composeGen,
    CoreStatisticsParserSpec.corestatsGen,
    ImportParserSpec.importGen,
    HighLevelSynthesisParserSpec.hlsGen,
    DesignSpaceExplorationParserSpec.dseGen
  )

  val jobsGen: Gen[String] = for {
    n <- Gen.choose(0, 500)
    s <- BasicParserSpec.join(0 until n map (_ => jobGen))
  } yield s
}
