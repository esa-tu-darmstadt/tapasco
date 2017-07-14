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
 * @file     PlatformTest.scala
 * @brief    Unit tests for Platform description file.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  json._
import  org.scalatest._
import  java.nio.file._

class PlatformSpec extends FlatSpec with Matchers {
  val jsonPath = Paths.get("json-examples").toAbsolutePath

  "A missing Platform file" should "throw an exception" in {
    assert(Platform.from(jsonPath.resolve("missing.json")).isLeft)
  }

  "A correct Platform file" should "be parsed to Right(Platform)" in {
    assert(Platform.from(jsonPath.resolve("correct-platform.json")).isRight)
  }

  "A correct Platform file" should "be parsed correctly" in {
    val oc = Platform.from(jsonPath.resolve("correct-platform.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    c.name should equal ("zynq")
    c.tclLibrary should equal (jsonPath.resolve("zynq.tcl"))
    c.part should equal ("xc7z045ffg900-2")
    c.boardPart should equal (Some("xilinx.com:zc706:part0:1.1"))
    c.boardPreset should equal (Some("ZC706"))
    c.targetUtilization should equal (55)
    c.supportedFrequencies should contain inOrderOnly (250, 200, 150, 100, 42)
  }

  "An Platform file with unknown entries" should "be parsed correctly" in {
    val oc = Platform.from(jsonPath.resolve("unknown-platform.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    c.name should equal ("zynq")
    c.tclLibrary should equal (jsonPath.resolve("zynq.tcl"))
    c.part should equal ("xc7z045ffg900-2")
    c.boardPart should equal (Some("xilinx.com:zc706:part0:1.1"))
    c.boardPreset should equal (Some("ZC706"))
    c.targetUtilization should equal (55)
    c.supportedFrequencies should contain inOrderOnly (250, 200, 150, 100, 42)
  }

  "An Platform file without a name" should "not be parsed" in {
    val oc1 = Platform.from(jsonPath.resolve("invalid-platform1.json"))
    val oc2 = Platform.from(jsonPath.resolve("invalid-platform2.json"))
    assert(oc1.isLeft)
    assert(oc2.isLeft)
  }

  "A Benchmark" should "be parsed correctly" in {
    val oc = Platform.from(jsonPath.resolve("correct-platform-benchmark.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    c.benchmark should not be empty
  }

  "A Platform with host frequency" should "be parsed correctly" in {
    val oc = Platform.from(jsonPath.resolve("correct-platform-hostfreq.json"))
    assert(oc.isRight)
    oc.right.get.hostFrequency should equal (Some(42.0))
  }

  "A Platform with mem frequency" should "be parsed correctly" in {
    val oc = Platform.from(jsonPath.resolve("correct-platform-memfreq.json"))
    assert(oc.isRight)
    oc.right.get.memFrequency should equal (Some(158.2))
  }
}
