package de.tu_darmstadt.cs.esa.tapasco.reports

import java.nio.file.Paths

import org.junit.runner.RunWith
import org.scalatest.junit.JUnitRunner
import org.scalatest.{FlatSpec, Matchers}

@RunWith(classOf[JUnitRunner])
class PortReportSpec extends FlatSpec with Matchers {
  val reportPath = Paths.get("src/test/resources/report-examples").toAbsolutePath

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
