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

class ParserSpec extends TaPaSCoSpec with Matchers with Checkers {
  import CommandLineParser._
  import Common._
  import ParserSpec._
  import org.scalacheck.Prop._

  "All valid command line argument strings" should "be correctly parsed" in
    check(forAllNoShrink(argsGen) { a =>
      checkParsed(P( args ~ End ).parse(a))
    })
}

private object ParserSpec {
  val argsGen: Gen[String] = BasicParserSpec.join(Seq(
    GlobalOptionsSpec.fullStringGen,
    JobParsersSpec.jobsGen
  ))
}
