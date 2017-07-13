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
 * @file     FeatureTest.scala
 * @brief    Unit tests for Features.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  org.scalatest._
import  java.nio.file._
import  json._

class FeatureSpec extends FlatSpec with Matchers {
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  val jsonPath = Paths.get("json-examples").toAbsolutePath.resolve("configTest")

  "LED Feature" should "be parsed correctly" in {
    val oc = Configuration.from(jsonPath.resolve("platform-led.json"))
    lazy val c = oc.right.get
    if (oc.isLeft) logger.error("parsing failed: {}", oc.left.get)
    assert(oc.isRight)
    c.jobs.head match {
      case job: ComposeJob =>
        job.features.get.length shouldBe (1)
        job.features.get.head shouldEqual (Feature("LED", Map("Enabled" -> "true")))
      case _ => assert(false, "expected ComposeJob")
    }
  }

  "OLED Feature" should "be parsed correctly" in {
    val oc = Configuration.from(jsonPath.resolve("platform-oled.json"))
    lazy val c = oc.right.get
    if (oc.isLeft) logger.error("parsing failed: {}", oc.left.get)
    assert(oc.isRight)
    c.jobs.head match {
      case job: ComposeJob =>
        job.features.get.length shouldBe (1)
        job.features.get.head shouldEqual (Feature("OLED", Map("Enabled" -> "true")))
      case _ => assert(false, "expected ComposeJob")
    }
  }

  "Cache Feature" should "be parsed correctly" in {
    val oc = Configuration.from(jsonPath.resolve("platform-cache.json"))
    lazy val c = oc.right.get
    if (oc.isLeft) logger.error("parsing failed: {}", oc.left.get)
    assert(oc.isRight)
    c.jobs.head match {
      case job: ComposeJob =>
        job.features.get.length shouldBe (1)
        job.features.get.head shouldEqual (Feature("Cache", Map(
          "Enabled" -> "true",
          "Associativity" -> "2",
          "Size" -> "32768"
        )))
      case _ => assert(false, "expected ComposeJob")
    }
  }

  "Debug Feature" should "be parsed correctly" in {
    val oc = Configuration.from(jsonPath.resolve("platform-debug.json"))
    lazy val c = oc.right.get
    if (oc.isLeft) logger.error("parsing failed: {}", oc.left.get)
    assert(oc.isRight)
    c.jobs.head match {
      case job: ComposeJob =>
        job.features.get.length shouldBe (1)
        job.features.get.head shouldEqual (Feature("Debug", Map(
          "Enabled" -> "true",
          "Depth" -> "4096",
          "Stages" -> "1",
          "Use Defaults" -> "false",
          "Nets" -> "[list *interrupt *HP0* *GP]")))
      case _ => assert(false, "expected ComposeJob")
    }

    val oc2 = Configuration.from(jsonPath.resolve("platform-debug2.json"))
    lazy val c2 = oc2.right.get
    if (oc2.isLeft) logger.error("parsing failed: {}", oc2.left.get)
    assert(oc2.isRight)
    c2.jobs.head match {
      case job: ComposeJob =>
        job.features.get.length shouldBe (1)
        job.features.get.head shouldEqual (Feature("Debug", Map("Enabled" -> "false")))
      case _ => assert(false, "expected ComposeJob")
    }
  }
}
