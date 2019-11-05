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
