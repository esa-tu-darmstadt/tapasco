package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.core.CorePanel
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.DescriptionPropertiesTable
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.chart._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.reports.SynthesisReport
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  CorePanel.Events._
import  scala.swing.{Label, ScrollPane, SplitPane, Swing}

/** CoreDetailPanel shows a several charts detailing information about
 *  the selected Core on all selected Targets.
 *  On top there is an instance of [[common.DescriptionPropertiesTable]], showing
 *  basic properties of the [[base.Core]] description. Below there are two chart
 *  areas, depicting relative resource utilization on all avaiable platforms, as
 *  well as max. operating frequency (as estimated by out-of-context synthesis).
 **/
class CoreDetailPanel extends SplitPane with Listener[CorePanel.Event] {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] final val PREFERRED_HEIGHT = 150

  def update(e: CorePanel.Event): Unit = e match {
    case CoreSelected(od: Option[Description]) => update(od)
    case _ => {}
  }

  // scalastyle:off cyclomatic.complexity
  private def update(oc: Option[Description]): Unit = Swing.onEDT {
    _logger.trace("new core: {}", oc map { _ match {
      case k: Kernel => k.name
      case c: Core => c.name
      case _ => "N/A"
    }} getOrElse "None")
    // reset bottom
    rightComponent = new Label("no synthesis data")

    leftComponent = new ScrollPane(new DescriptionPropertiesTable(oc)) {
      preferredSize = new java.awt.Dimension(0, PREFERRED_HEIGHT)
    }

    val checkReports = oc map { c => c match {
      case _: Kernel => true
      case _: Core => true
    } } getOrElse false

    if (checkReports) {
      oc.get match {
        case k: Kernel =>
          _logger.trace("platforms: {}", FileAssetManager.entities.platforms map (_.name))
          val reports: Map[String, SynthesisReport] = (for {
            t <- FileAssetManager.entities.targets
            r <- FileAssetManager.reports.synthReport(k.name, t)
          } yield "%s@%s".format(t.pd.name, t.ad.name) -> r).toMap

          _logger.trace("reports: {}", reports.keys.toString)

          if (reports.size > 0) rightComponent = new SynthesisReportsChart(reports)

        case c: Core =>
          _logger.trace("platforms: {}", FileAssetManager.entities.platforms map (_.name))
          val reports: Map[String, SynthesisReport] = (for {
            t <- FileAssetManager.entities.targets
            r <- FileAssetManager.reports.synthReport(c.name, t)
          } yield "%s@%s".format(t.pd.name, t.ad.name) -> r).toMap

          _logger.trace("reports: {}", reports.keys.toString)

          if (reports.size > 0) rightComponent = new SynthesisReportsChart(reports)
      }
      Swing.onEDT { dividerLocation = .25 }
    }

    revalidate()
    repaint()
  }
  // scalastyle:on cyclomatic.complexity
}
