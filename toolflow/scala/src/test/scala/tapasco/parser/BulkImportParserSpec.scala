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

class BulkImportParserSpec extends TaPaSCoSpec with Matchers with Checkers {
  import BulkImportParser._
  import BulkImportParserSpec._
  import Common._
  import Prop._

  "All valid job specs" should "be parsed correctly by bulkimport" in
    check(forAllNoShrink(bulkImportGen) { bij =>
      checkParsed( P( bulkimport ~ End ).parse(bij) )
    })
}

private object BulkImportParserSpec {
  /* @{ Generators and Arbitraries */
  val bulkImportGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.anyCase("bulkimport"),
    for { p <- GlobalOptionsSpec.pathGen } yield p.toString
  ))
  /* Generators and Arbitraries @} */
}
