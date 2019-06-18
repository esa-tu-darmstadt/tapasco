//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
/**
 * @file     CompositionTest.scala
 * @brief    Unit tests for Composition description file.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  java.nio.file._
import  json._
import  org.scalacheck.Prop._

class CompositionSpec extends FlatSpec with Matchers with Checkers {
  val jsonPath = Paths.get("json-examples").toAbsolutePath

  "All valid compositions" should "be read and written correctly" in {
    check(forAll { composition: Composition =>
      val pc = Composition.from(Composition.to(composition))
      pc.isRight && pc.right.get.equals(composition)
    })
  }

  "A missing Composition file" should "throw an exception" in {
    assert(Composition.from(jsonPath.resolve("missing.json")).isLeft)
  }

  "A correct Composition file" should "be parsed to Some(Composition)" in {
    assert(Composition.from(jsonPath.resolve("correct-composition.json")).isRight)
  }

  "A correct Composition file" should "be parsed correctly" in {
    val oc = Composition.from(jsonPath.resolve("correct-composition.json"))
    lazy val c: Composition = oc.right.get
    assert(oc.isRight)
    c.description should equal (Some("Test"))
    c.composition.length should equal (2)
    c.composition(0).kernel should equal ("sudoku")
    c.composition(0).count should be (1)
    c.composition(1).kernel should be ("warraw")
    c.composition(1).count should be (2)
  }

  "A Composition file with unknown entries" should "be parsed correctly" in {
    val oc = Composition.from(jsonPath.resolve("unknown-composition.json"))
    lazy val c: Composition = oc.right.get
    assert(oc.isRight)
    c.description should equal (Some("Test"))
    c.composition.length should equal (2)
    c.composition(0).kernel should equal ("sudoku")
    c.composition(0).count should be (1)
    c.composition(1).kernel should be ("warraw")
    c.composition(1).count should be (2)
  }

  "A Composition file with invalid entries" should "not be parsed" in {
    val oc1 = Composition.from(jsonPath.resolve("invalid-count1-composition.json"))
    val oc2 = Composition.from(jsonPath.resolve("invalid-count2-composition.json"))
    val oc3 = Composition.from(jsonPath.resolve("invalid-count3-composition.json"))
    assert(oc1.isLeft)
    assert(oc2.isLeft)
    assert(oc3.isLeft)
  }

  /* @{ Generators and Arbitraries */
  import org.scalacheck._
  val genEntry: Gen[Composition.Entry] = for {
    name <- Arbitrary.arbitrary[String] suchThat (_.length > 0)
    count <- Gen.choose(1, 128)
  } yield Composition.Entry(name, count)
  implicit val arbEntry: Arbitrary[Composition.Entry] = Arbitrary(genEntry)

  def truncate(cs: Seq[Composition.Entry], left: Int = 128): Seq[Composition.Entry] = if (cs.isEmpty)
    cs
  else
    if (cs.head.count > left)
      Seq()
    else
      cs.head +: truncate(cs.tail, left - cs.head.count)

  val genComposition: Gen[Composition] = for {
    composition <- Arbitrary.arbitrary[Seq[Composition.Entry]] suchThat (_.length > 0)
    description <- Arbitrary.arbitrary[Option[String]]
  } yield (Composition(java.nio.file.Paths.get("N/A"), description, truncate(composition)))
  implicit val arbComposition: Arbitrary[Composition] = Arbitrary(genComposition)

  /* Generators and Arbitraries @} */
}
