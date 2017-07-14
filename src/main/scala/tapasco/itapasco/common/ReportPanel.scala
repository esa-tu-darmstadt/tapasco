package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  de.tu_darmstadt.cs.esa.tapasco.reports._
import  scala.swing.{BorderPanel, Label, ScrollPane, Table}

/** ReportPanel is a UI element to display any [[reports.Report]] instance.
 *  Displays data found in the report in the form of a scrollable Table.
 **/
class ReportPanel extends BorderPanel {
  private[this] final val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] final val _noReport = new Label("no report")
  private[this] var _report: Option[Report] = None

  layout(_noReport) = BorderPanel.Position.Center

  def report: Option[Report] = _report
  def report_=(r: Report) {
    _logger.trace("setting report: {}", r)
    layout(new ScrollPane(new ReportPanel.ReportTable(r))) = BorderPanel.Position.Center
    revalidate()
    repaint()
  }
}

private object ReportPanel {
  class ReportTable(r: Report) extends Table(mkData(r), Seq("Property", "Value")) {
    model = NonEditable(model)
    peer.getTableHeader().setReorderingAllowed(false)
  }

  def mkData(r: Report): Array[Array[Any]] = r match {
    case cr: CoSimReport       => mkData(cr)
    case pr: PowerReport       => mkData(pr)
    case sr: SynthesisReport   => mkData(sr)
    case tr: TimingReport      => mkData(tr)
    case ur: UtilizationReport => mkData(ur)
    case _                     => Array(Array[Any]())
  }

  def mkData(sr: SynthesisReport): Array[Array[Any]] = Array(
    Array("File", sr.file.toString),
    Array("Slices", sr.area map (ar => "%d / %d (%1.1f%%)".format(ar.resources.SLICE, ar.available.SLICE, ar.slice)) getOrElse "N/A"),
    Array("LUTs", sr.area map (ar => "%d / %d (%1.1f%%)".format(ar.resources.LUT, ar.available.LUT, ar.lut)) getOrElse "N/A"),
    Array("FF", sr.area map (ar => "%d / %d (%1.1f%%)".format(ar.resources.FF, ar.available.FF, ar.ff)) getOrElse "N/A"),
    Array("DSP", sr.area map (ar => "%d / %d (%1.1f%%)".format(ar.resources.DSP, ar.available.DSP, ar.dsp)) getOrElse "N/A"),
    Array("BRAM", sr.area map (ar => "%d / %d (%1.1f%%)".format(ar.resources.BRAM, ar.available.BRAM, ar.bram)) getOrElse "N/A"),
    Array("Has met timing?", sr.timing map (_.hasMetTiming) getOrElse ""),
    Array("Target clock period (ns)", sr.timing map (_.targetPeriod) getOrElse "N/A"),
    Array("Actual clock period (ns)", sr.timing map (_.clockPeriod) getOrElse "N/A")
  )

  def mkData(cr: CoSimReport): Array[Array[Any]] = Array(
    Array("File", cr.file.toString),
    Array("Min. Latency (clock cycles)", cr.latency.min),
    Array("Avg. Latency (clock cycles)", cr.latency.avg),
    Array("Max. Latency (clock cycles)", cr.latency.max),
    Array("Min. Interval (clock cycles)", cr.interval.min),
    Array("Avg. Interval (clock cycles)", cr.interval.avg),
    Array("Max. Interval (clock cycles)", cr.interval.max)
  )

  def mkData(pr: PowerReport): Array[Array[Any]] = Array(
    Array("File", pr.file.toString),
    Array("Total on-chip power (W)", pr.totalOnChipPower getOrElse "N/A"),
    Array("Dynamic power (W)", pr.dynamicPower getOrElse "N/A"),
    Array("Static power (W)", pr.staticPower getOrElse "N/A"),
    Array("Confidence Level", pr.confidenceLevel getOrElse "")
  )

  def mkData(tr: TimingReport): Array[Array[Any]] = Array(
    Array("File", tr.file.toString),
    Array("Worst negative slack (ns)", tr.worstNegativeSlack),
    Array("Max. Data Path Delay (ns)", tr.dataPathDelay),
    Array("Max. Delay Data Path Source", tr.maxDelayPath.source),
    Array("Max. Delay Data Path Dest", tr.maxDelayPath.destination),
    Array("Max. Delay Data Path Slack", tr.maxDelayPath.slack),
    Array("Min. Delay Data Path Source", tr.minDelayPath.source),
    Array("Min. Delay Data Path Dest", tr.minDelayPath.destination),
    Array("Min. Delay Data Path Slack", tr.minDelayPath.slack),
    Array("Timing met", tr.timingMet)
  )

  def mkData(ur: UtilizationReport): Array[Array[Any]] = Array(
    Array("File", ur.file.toString),
    Array("Total Slices", "%d / %d (%1.1f%%)".format(ur.used.SLICE, ur.available.SLICE, ur.used.SLICE / ur.available.SLICE.toDouble)),
    Array("Total LUTs", "%d / %d (%1.1f%%)".format(ur.used.LUT, ur.available.LUT, ur.used.LUT / ur.available.LUT.toDouble)),
    Array("Total FFs", "%d / %d (%1.1f%%)".format(ur.used.FF, ur.available.FF, ur.used.FF / ur.available.FF.toDouble)),
    Array("Total DSP", "%d / %d (%1.1f%%)".format(ur.used.DSP, ur.available.DSP, ur.used.DSP / ur.available.DSP.toDouble)),
    Array("Total BRAM", "%d / %d (%1.1f%%)".format(ur.used.BRAM, ur.available.BRAM, ur.used.BRAM / ur.available.BRAM.toDouble))
  )
}
