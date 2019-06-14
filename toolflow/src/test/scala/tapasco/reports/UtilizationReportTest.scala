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
 * @file     UtilizationReportTest.scala
 * @brief    Unit tests for UtilizationReport model.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import  org.scalatest._
import  java.nio.file._

class UtilizationReportSpec extends FlatSpec with Matchers {
  val reportPath = Paths.get("report-examples").toAbsolutePath

  "A missing UtilizationReport file" should "result in None" in {
    UtilizationReport(reportPath.resolve("missing.rpt")) shouldBe empty
  }

  "An invalid UtilizationReport file" should "result in None" in {
    UtilizationReport(reportPath.resolve("correct-timing.rpt")) shouldBe empty
    UtilizationReport(reportPath.resolve("invalid-cosim1.rpt")) shouldBe empty
  }

  "A correct UtilizationReport file" should "be parsed correctly" in {
    val oc = UtilizationReport(reportPath.resolve("correct-util1.rpt"))
    lazy val r = oc.get
    oc should not be empty
    r.used.SLICE should be (210)
    r.used.LUT should be (557)
    r.used.FF should be (800)
    r.used.BRAM should be (1)
    r.used.DSP should be (2)
    r.available.SLICE should be (108300)
    r.available.LUT should be (433200)
    r.available.FF should be (866400)
    r.available.BRAM should be (1470)
    r.available.DSP should be (3600)
  }

  "Partial UtilizationReport files" should "be parsed correctly" in {
    val oc = UtilizationReport(reportPath.resolve("partial-util1.rpt"))
    lazy val r = oc.get
    oc should not be empty
    r.used.SLICE should be (UtilizationReport.InvalidValue)
    r.used.LUT should be (557)
    r.used.FF should be (800)
    r.used.BRAM should be (1)
    r.used.DSP should be (2)
    r.available.SLICE should be (UtilizationReport.InvalidValue)
    r.available.LUT should be (433200)
    r.available.FF should be (866400)
    r.available.BRAM should be (1470)
    r.available.DSP should be (3600)
    val oc2 = UtilizationReport(reportPath.resolve("partial-util2.rpt"))
    lazy val r2 = oc2.get
    oc2 should not be empty
    r2.used.SLICE should be (210)
    r2.used.LUT should be (557)
    r2.used.FF should be (800)
    r2.used.BRAM should be (UtilizationReport.InvalidValue)
    r2.used.DSP should be (2)
    r2.available.SLICE should be (108300)
    r2.available.LUT should be (433200)
    r2.available.FF should be (866400)
    r2.available.BRAM should be (UtilizationReport.InvalidValue)
    r2.available.DSP should be (3600)
  }
}
