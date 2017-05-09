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
 * @file     SynthesisReportTest.scala
 * @brief    Unit tests for SynthesisReport model.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.reports
import org.scalatest._
import java.nio.file._

class SynthesisReportSpec extends FlatSpec with Matchers {
  val reportPath = Paths.get("report-examples").toAbsolutePath

  "A missing SynthesisReport file" should "result in None" in {
    SynthesisReport(reportPath.resolve("missing.rpt")) shouldBe empty
  }

  "An invalid SynthesisReport file" should "result in None" in {
    SynthesisReport(reportPath.resolve("correct-timing.rpt")) shouldBe empty
    SynthesisReport(reportPath.resolve("invalid-synth1.rpt")) shouldBe empty
  }

  "A correct SynthesisReport file" should "be parsed correctly" in {
    val oc = SynthesisReport(reportPath.resolve("correct-synth1.rpt"))
    lazy val r = oc.get
    oc should not be empty
    r.area should not be empty
    r.timing should not be empty
    r.area.get.resources.SLICE should be (215)
    r.area.get.resources.LUT should be (538)
    r.area.get.resources.FF should be (776)
    r.area.get.resources.DSP should be (0)
    r.area.get.resources.BRAM should be (0)
    r.area.get.available.SLICE should be (13300)
    r.area.get.available.LUT should be (53200)
    r.area.get.available.FF should be (106400)
    r.area.get.available.DSP should be (220)
    r.area.get.available.BRAM should be (140)
    r.timing.get.targetPeriod should be (2.2222222222222223)
    r.timing.get.clockPeriod should be (4.836)
    val oc2 = SynthesisReport(reportPath.resolve("correct-synth2.rpt"))
    lazy val r2 = oc2.get
    oc2 should not be empty
    r2.area should not be empty
    r2.timing should not be empty
    r2.area.get.resources.SLICE should be (232)
    r2.area.get.resources.LUT should be (542)
    r2.area.get.resources.FF should be (781)
    r2.area.get.resources.DSP should be (0)
    r2.area.get.resources.BRAM should be (0)
    r2.area.get.available.SLICE should be (54650)
    r2.area.get.available.LUT should be (218600)
    r2.area.get.available.FF should be (437200)
    r2.area.get.available.DSP should be (900)
    r2.area.get.available.BRAM should be (545)
    r2.timing.get.targetPeriod should be (2.2222222222222223)
    r2.timing.get.clockPeriod should be (2.65)
    val oc3 = SynthesisReport(reportPath.resolve("correct-synth3.rpt"))
    lazy val r3 = oc3.get
    oc3 should not be empty
    r3.area should not be empty
    r3.timing should not be empty
    r3.area.get.resources.SLICE should be (215)
    r3.area.get.resources.LUT should be (543)
    r3.area.get.resources.FF should be (779)
    r3.area.get.resources.DSP should be (0)
    r3.area.get.resources.BRAM should be (0)
    r3.area.get.available.SLICE should be (108300)
    r3.area.get.available.LUT should be (433200)
    r3.area.get.available.FF should be (866400)
    r3.area.get.available.DSP should be (3600)
    r3.area.get.available.BRAM should be (1470)
    r3.timing.get.targetPeriod should be (2.2222222222222223)
    r3.timing.get.clockPeriod should be (2.705)
  }

  "Partial SynthesisReports" should "be parsed correctly" in {
    val oc1 = SynthesisReport(reportPath.resolve("partial-synth1.rpt"))
    lazy val r1 = oc1.get
    oc1 should not be empty
    r1.area shouldBe empty
    r1.timing should not be empty
    r1.timing.get.targetPeriod should be (2.2222222222222223)
    r1.timing.get.clockPeriod should be (4.836)

    val oc2 = SynthesisReport(reportPath.resolve("partial-synth2.rpt"))
    lazy val r2 = oc2.get
    oc2 should not be empty
    r2.area should not be empty
    r2.timing shouldBe empty
    r2.area.get.resources.SLICE should be (215)
    r2.area.get.resources.LUT should be (538)
    r2.area.get.resources.FF should be (776)
    r2.area.get.resources.DSP should be (0)
    r2.area.get.resources.BRAM should be (0)
    r2.area.get.available.SLICE should be (13300)
    r2.area.get.available.LUT should be (53200)
    r2.area.get.available.FF should be (106400)
    r2.area.get.available.DSP should be (220)
    r2.area.get.available.BRAM should be (140)
  }
}

