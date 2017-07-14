package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.dse.Alternatives
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  scala.swing.event._
import  scala.swing.BorderPanel.Position._

/** DSE configuration panel: Show alternatives for each Core in current Composition.
 *  UI element to select/deselect the alternatives variation in the [[dse.DesignSpace]].
 *  Shows on table for each kernel in the current [[base.Composition]] with possible
 *  alternatives (based on ID).
 */
class AlternativeVariationPanel extends BorderPanel with Listener[Job.Event]{
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] var state   = !Job.job.dimensions.alternatives
  private[this] val _cb     = new CheckBox("Alternative Cores Variation") { selected = state }

  update()
  Job += this
  listenTo(_cb)
  reactions += {
    case ButtonClicked(`_cb`) => Job.job = Job.job.copy(
      dimensions = Job.job.dimensions.copy(alternatives = _cb.selected)
    )
  }

  def update(e: Job.Event): Unit = e match {
    case Job.Events.JobChanged(job) => update()
  }

  private def update(): Unit = if (state != Job.job.dimensions.alternatives) {
    _logger.trace("switching to new state: {}", Job.job.dimensions.alternatives)
    Swing.onEDT {
      state = Job.job.dimensions.alternatives
      _cb.selected = state
      layout.clear()
      layout(new FlowPanel { contents += _cb }) = North
      if (Job.job.dimensions.alternatives) {
        layout(new BoxPanel(Orientation.Vertical) {
          for (ce <- Job.job.initialComposition.composition) {
            contents += mkAltPanel(ce.kernel)
          }
        }) = Center
      }
      revalidate()
      repaint()
    }
  } else {
    _logger.trace("state already matches: {}", state)
  }

  private def mkAltPanel(kernel: String) = new BorderPanel {
    private[this] val alts = Alternatives.alternatives(kernel, Job.job.target)(Config.configuration)
    _logger.trace("alternatives: {}", alts.toString)
    layout(new Label("Alternatives for " + kernel)) = North
    layout(new ScrollPane(NonEditable(new Table((alts map (a => Array(a: Any))).toArray,
      Seq("Alternatives for " + kernel))))) = Center
  }
}
