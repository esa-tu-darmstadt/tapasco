package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.core
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing.GridPanel

/** Panel that displays an estimation for area utilization and max. frequency for
 *  the currently configured Composition. Uses a GridPanel, where each
 *  [[base.Architecture]] has its own row and each [[base.Platform]] its own
 *  column.
 *
 *  @note Currently all reports must be available (requirement).
 */
class CompositionSummariesPanel extends GridPanel(
    Job.job.architectures.size,
    Job.job.platforms.size) with Listener[Job.Event] {
  // listen to model changes
  Job += this

  /** Update set of summary panels if composition changes. */
  def update(e: Job.Event): Unit = {
    contents.clear()
    rows = Job.job.architectures.size
    columns = Job.job.platforms.size
    if (! Job.job.initialComposition.isEmpty) {
      for (t <- Job.job.targets) {
        contents += new CompositionTargetSummaryPanel(Config.configuration,
          Job.job.initialComposition, t)
      }
    }
    revalidate()
  }
}
