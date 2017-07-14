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
 * @file     CoreTest.scala
 * @brief    Unit tests for Core description file.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  json._
import  org.scalatest._
import  java.nio.file._

class CoreSpec extends FlatSpec with Matchers {
  private final lazy val logger =
    de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  val jsonPath = Paths.get("json-examples").toAbsolutePath

  "A missing Core file" should "throw an exception" in {
    assert(Core.from(jsonPath.resolve("missing.json")).isLeft)
  }

  "A correct Core file" should "be parsed to Right(Core)" in {
    assert(Core.from(jsonPath.resolve("correct-core.json")).isRight)
  }

  "A correct Core file" should "be parsed correctly" in {
    val oc = Core.from(jsonPath.resolve("correct-core.json"))
    lazy val c = oc.right.get
    if (oc.isLeft) logger.error("parsing failed: {}", oc.left.get)
    assert(oc.isRight)
    c.name should equal ("TestCore")
    c.version should equal ("0.1")
    c.id should equal (42)
    c.description should equal (Some("A correct core description."))
    c.zipPath.toFile.exists should be (true)
    c.averageClockCycles should equal (Some(1234567890))
  }

  "A Core file with unknown entries" should "be parsed correctly" in {
    val oc = Core.from(jsonPath.resolve("unknown-core.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    c.name should equal ("TestCore")
    c.version should equal ("0.1")
    c.id should equal (42)
    c.description should equal (Some("A correct core description."))
    c.zipPath.toFile.exists should be (true)
  }

  "An invalid Core file" should "not be parsed" in {
    val oc1 = Core.from(jsonPath.resolve("invalid-core1.json"))
    val oc2 = Core.from(jsonPath.resolve("invalid-core2.json"))
    val oc3 = Core.from(jsonPath.resolve("invalid-core3.json"))
    val oc4 = Core.from(jsonPath.resolve("invalid-core4.json"))
    assert(oc1.isLeft)
    assert(oc2.isLeft)
    assert(oc3.isLeft)
    assert(oc4.isLeft)
  }
}
