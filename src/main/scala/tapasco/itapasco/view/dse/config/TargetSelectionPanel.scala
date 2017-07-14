package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._

/** TargetSelectionPanel shows a radio button group for the selection
 *  of one of the targets currently configured.
 */
class TargetSelectionPanel extends BorderPanel {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  refresh()

  Job += new Listener[Job.Event] {
    def update(e: Job.Event): Unit = refresh()
  }

  FileAssetManager.entities += new Listener[EntityManager.Event] {
    def update(e: EntityManager.Event): Unit = refresh()
  }

  def refresh(): Unit = {
    val targets = FileAssetManager.entities.targets.toSeq.sortBy(_.toString)
    val rows = FileAssetManager.entities.architectures.size
    val cols = FileAssetManager.entities.platforms.size
    _logger.trace("targets = {}", targets.mkString(", "))
    val buttons = mkButtonGroup(targets)
    Swing.onEDT {
      layout(new Label("Select target:")) = BorderPanel.Position.West
      layout(new GridPanel(rows, cols) {
        contents ++= buttons.buttons
      }) = BorderPanel.Position.Center
      revalidate()
      repaint()
    }
  }

  private def mkButtonGroup(targets: Seq[Target]): ButtonGroup = new ButtonGroup(
    targets map { t => new RadioButton() {
      selected = Job.job.targets.headOption map (_.equals(t)) getOrElse false
      action = Action(t.toString) {
        _logger.trace("{} was selected", t.toString)
        Job.job = Job.job.copy(
          _architectures = Some(Seq(t.ad.name)),
          _platforms     = Some(Seq(t.pd.name))
        )
      }
    }}: _*
  )
}
