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
/**
  * @file CoreTest.scala
  * @brief Unit tests for Core description file.
  * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
  **/
package tapasco.base

import org.scalatest._
import tapasco.TaPaSCoSpec
import tapasco.base.json._

class CoreSpec extends TaPaSCoSpec with Matchers {
  private final lazy val logger =
    tapasco.Logging.logger(getClass)

  "A missing Core file" should "throw an exception" in {
    assert(Core.from(jsonPath.resolve("missing.json"))(validatingCoreReads(jsonPath)).isLeft)
  }

  "A correct Core file" should "be parsed to Right(Core)" in {
    assert(Core.from(jsonPath.resolve("correct-core.json"))(validatingCoreReads(jsonPath)).isRight)
  }

  "A correct Core file" should "be parsed correctly" in {
    val oc = Core.from(jsonPath.resolve("correct-core.json"))(validatingCoreReads(jsonPath))
    lazy val c = oc.right.get
    if (oc.isLeft) logger.error("parsing failed: {}", oc.left.get)
    assert(oc.isRight)
    c.name should equal("TestCore")
    c.version should equal("0.1")
    c.id should equal(42)
    c.description should equal(Some("A correct core description."))
    c.zipPath.toFile.exists should be(true)
    c.averageClockCycles should equal(Some(1234567890))
  }

  "A Core file with unknown entries" should "be parsed correctly" in {
    val oc = Core.from(jsonPath.resolve("unknown-core.json"))(validatingCoreReads(jsonPath))
    lazy val c = oc.right.get
    assert(oc.isRight)
    c.name should equal("TestCore")
    c.version should equal("0.1")
    c.id should equal(42)
    c.description should equal(Some("A correct core description."))
    c.zipPath.toFile.exists should be(true)
  }

  "An invalid Core file" should "not be parsed" in {
    val oc1 = Core.from(jsonPath.resolve("invalid-core1.json"))(validatingCoreReads(jsonPath))
    val oc2 = Core.from(jsonPath.resolve("invalid-core2.json"))(validatingCoreReads(jsonPath))
    val oc3 = Core.from(jsonPath.resolve("invalid-core3.json"))(validatingCoreReads(jsonPath))
    val oc4 = Core.from(jsonPath.resolve("invalid-core4.json"))(validatingCoreReads(jsonPath))
    assert(oc1.isLeft)
    assert(oc2.isLeft)
    assert(oc3.isLeft)
    assert(oc4.isLeft)
  }
}
