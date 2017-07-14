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
/**
 * @file     PowerReportTest.scala
 * @brief    Unit tests for PowerReport model.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import  org.scalatest._
import  java.nio.file._

class PowerReportSpec extends FlatSpec with Matchers {
  val reportPath = Paths.get("report-examples").toAbsolutePath

  "A missing PowerReport file" should "result in None" in {
    PowerReport(reportPath.resolve("missing.rpt")) shouldBe empty
  }

  "An invalid PowerReport file" should "result in None" in {
    PowerReport(reportPath.resolve("correct-timing.rpt")) shouldBe empty
  }

  "A correct PowerReport file" should "be parsed correctly" in {
    val oc = PowerReport(reportPath.resolve("correct-power1.rpt"))
    lazy val r = oc.get
    oc should not be empty
    r.totalOnChipPower should be (Some(0.33))
    r.dynamicPower should be (Some(0.006))
    r.staticPower should be (Some(0.324))
    r.confidenceLevel should be (Some("Low"))
    val oc2 = PowerReport(reportPath.resolve("correct-power2.rpt"))
    lazy val r2 = oc2.get
    oc2 should not be empty
    r2.totalOnChipPower should be (Some(0.231))
    r2.dynamicPower should be (Some(0.007))
    r2.staticPower should be (Some(0.224))
    r2.confidenceLevel should be (Some("Low"))
    val oc3 = PowerReport(reportPath.resolve("correct-power3.rpt"))
    lazy val r3 = oc3.get
    oc3 should not be empty
    r3.totalOnChipPower should be (Some(0.123))
    r3.dynamicPower should be (Some(0.005))
    r3.staticPower should be (Some(0.118))
    r3.confidenceLevel should be (Some("Low"))
  }
}
