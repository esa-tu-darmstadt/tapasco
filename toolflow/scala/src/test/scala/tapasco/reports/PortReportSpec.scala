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

package tapasco.reports

import org.scalatest.Matchers
import tapasco.TaPaSCoSpec

class PortReportSpec extends TaPaSCoSpec with Matchers {

  "A missing PortReport file" should "result in None" in {
    PortReport(reportPath.resolve("missing.rpt")) shouldBe empty
  }

  "An invalid PortReport file" should "result in None" in {
    PortReport(reportPath.resolve("correct-timing.rpt")) shouldBe empty
  }

  "A correct PortReport file" should "be parsed to Some(PortReport)" in {
    PortReport(reportPath.resolve("correct-port.rpt")) should not be empty
  }

  "A correct PortReport file" should "be parsed correctly" in {
    val pr = PortReport(reportPath.resolve("correct-port.rpt"))
    pr should not be empty
    pr.get.numMasters shouldBe 42
    pr.get.numSlaves shouldBe 25
  }
}
