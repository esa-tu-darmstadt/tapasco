package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.chart._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.reports.SynthesisReport
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing.{BorderPanel, Component, GridPanel, Label}
import  scala.swing.BorderPanel.Position._
import  java.awt.Color

/**
 * CompositionPanel shows pie charts for each currently selected target,
 * indicating the proportional size of each configured kernel in the overal
 * area of the Composition.
 **/
class CompositionPanel extends BorderPanel with Listener[Job.Event] {
  import CompositionPanel._
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  /** Update charts, if selected targets or the composition change. */
  def update(e: Job.Event): Unit = update()

  private def update(): Unit = if (Job.job.initialComposition.isEmpty) {
    layout(new Label("no composition")) = Center
  } else {
    layout(mkOverview(Job.job.initialComposition)) = Center
  }

  private def mkOverview(c: Composition): Component =
    new GridPanel(rowsFromModel, colsFromModel) {
      for (t <- Job.job.targets) {
        // get the reports for all kernels
        val reports: Map[String, Option[SynthesisReport]] = (for {
          ce <- c.composition
        } yield ce.kernel -> FileAssetManager.reports.synthReport(ce.kernel, t)).toMap
        // check if any reports are missing
        val missing = reports filter (_._2.isEmpty)
        // show missing data label instead of pie chart
        if (missing.size > 0) {
          _logger.warn("missing synthesis reports: {}", missing.toString)
          contents += new Label("missing data") { foreground = Color.red }
        } else {
          // make pie chart of area utilization
          contents += new AreaChart((for {
            name <- reports.keys.toSeq.sorted
            report <- reports(name)
            area <- report.area
            count <- c.composition.find(_.kernel.equals(name))
          } yield name -> area * count.count).toMap, Some(t.toString))
        }
      }
    }

  Job += this
}

object CompositionPanel {
  private def rowsFromModel: Int = {
    logger.trace("architecture filter: {}", Job.job.architectures map (_.name))
    Job.job.architectures.size
  }

  private def colsFromModel: Int = {
    logger.trace("platform filter: {}", Job.job.platforms map (_.name))
    Job.job.platforms.size
  }

  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
}
