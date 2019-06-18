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
 * @file     ArchitectureTest.scala
 * @brief    Unit tests for Architecture description file.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  json._
import  org.scalatest._
import  java.nio.file._

class ArchitectureSpec extends FlatSpec with Matchers {
  val jsonPath = Paths.get("json-examples").toAbsolutePath

  "A missing Architecture file" should "throw an exception" in {
    assert(Architecture.from(jsonPath.resolve("missing.json")).isLeft)
  }

  "A correct Architecture file" should "be parsed to Right" in {
    assert(Architecture.from(jsonPath.resolve("correct-arch.json")).isRight)
  }

  "A correct Architecture file" should "be parsed correctly" in {
    val oc = Architecture.from(jsonPath.resolve("correct-arch.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    c.name should equal ("axi4mm")
    c.tclLibrary should equal (jsonPath.resolve("axi4mm.tcl"))
    c.valueArgTemplate should equal (jsonPath.resolve("valuearg.directives.template"))
    c.referenceArgTemplate should equal (jsonPath.resolve("referencearg.directives.template"))
  }

  "An Composition file with unknown entries" should "be parsed correctly" in {
    val oc = Architecture.from(jsonPath.resolve("unknown-arch.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    c.name should equal ("axi4mm")
    c.tclLibrary should equal (jsonPath.resolve("axi4mm.tcl"))
    c.valueArgTemplate should equal (jsonPath.resolve("valuearg.directives.template"))
    c.referenceArgTemplate should equal (jsonPath.resolve("referencearg.directives.template"))
  }

  "An Architecture file without a name" should "not be parsed" in {
    val oc = Architecture.from(jsonPath.resolve("invalid-arch.json"))
    assert(oc.isLeft)
  }

  "An Architecture file with missing files" should "be parsed as Left" in {
    val oc = Architecture.from(jsonPath.resolve("missing-file-arch.json"))
    assert(oc.isLeft)
  }
}
