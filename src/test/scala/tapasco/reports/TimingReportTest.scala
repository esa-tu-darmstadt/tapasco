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
 * @file     TimingReportTest.scala
 * @brief    Unit tests for TimingReport model.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import org.scalatest._
import java.nio.file._

class TimingReportSpec extends FlatSpec with Matchers {
  val reportPath = Paths.get("report-examples").toAbsolutePath

  "A missing TimingReport file" should "result in None" in {
    TimingReport(reportPath.resolve("missing.rpt")) shouldBe empty
  }

  "An invalid TimingReport file" should "result in None" in {
    TimingReport(reportPath.resolve("correct-power1.rpt")) shouldBe empty
  }

  "A correct TimingReport file" should "be parsed to Some(TimingReport)" in {
    TimingReport(reportPath.resolve("correct-timing.rpt")) should not be empty
  }

  "A correct TimingReport file" should "be parsed correctly" in {
    val oc = TimingReport(reportPath.resolve("correct-timing.rpt"))
    lazy val c = oc.get
    oc should not be empty
    c.worstNegativeSlack shouldBe -5.703
    c.dataPathDelay shouldBe 7.604

    c.maxDelayPath.source shouldBe "stereoCore_stereo_disparityRows_7_dispCalc/deg0Calc_4_lValOut/empty_reg_reg/C"
    c.maxDelayPath.destination shouldBe "stereoCore_stereo_disparityRows_7_dispCalc/minLValsFinder_comps_0_finders_0_1_out/data1_reg_reg[5]/D"
    c.maxDelayPath.slack shouldBe -5.703

    c.minDelayPath.source shouldBe "stereoCore_stereo_interRow_2/deg45_ifc_lvalHandler_storeVals_out_rv_reg[80]/C"
    c.minDelayPath.destination shouldBe "stereoCore_stereo_interRow_2/deg45_ifc_lvalHandler_curLine_rv_reg[80]/D"
    c.minDelayPath.slack shouldBe 0.026
  }

  "An invalid TimingReport file" should "not be parsed" in {
    val oc1 = TimingReport(reportPath.resolve("invalid-timing1.rpt"))
    val oc2 = TimingReport(reportPath.resolve("invalid-timing2.rpt"))
    val oc3 = TimingReport(reportPath.resolve("invalid-timing3.rpt"))
    oc1 shouldBe empty
    oc2 shouldBe empty
    oc3 shouldBe empty
  }
}
