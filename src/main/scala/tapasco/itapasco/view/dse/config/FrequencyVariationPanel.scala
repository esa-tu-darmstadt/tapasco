package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  scala.swing.event._
import  scala.swing.BorderPanel.Position._

/** FrequencyVariationPanel provides UI elements to configure frequency variation
 *  in the design space.
 *  Frequency variation can be selected/deselected, in which case either an
 *  instance of [[FixedFrequencyPanel]] or a table depicting all frequency values
 *  in the valid range for current composition. Validity is computed by the
 *  [[dse.DesignSpace]], which determines the maximal frequency as an upper bound
 *  on the maximal frequencies for each kernel in the composition (as per
 *  out-of-context synthesis).
 */
class FrequencyVariationPanel extends BorderPanel with Listener[Job.Event] {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] var state   = !Job.job.dimensions.frequency
  private[this] val _cb     = new CheckBox("Design Frequency Variation") { selected = state }

  def update(e: Job.Event): Unit = e match {
    case Job.Events.JobChanged(job) => update()
  }

  private def update(): Unit = if (state != Job.job.dimensions.frequency) {
    _logger.trace("switching to new state: {}", Job.job.dimensions.frequency)
    Swing.onEDT {
      layout.clear()
      layout(new FlowPanel { contents += _cb }) = North
      layout(mkCenter) = Center
      state = Job.job.dimensions.frequency
      _cb.selected = state
      revalidate()
      repaint()
    }
  } else {
    _logger.trace("state already matches: {}", Job.job.dimensions.frequency)
  }

  private def mkCenter = new BorderPanel {
    _logger.trace("dims: {}", Job.job.dimensions)
    if (Job.job.dimensions.frequency) {
      val t = Job.job.target
      val ff = DesignSpace.feasibleFreqs(Job.job.target, Job.job.initialComposition)
      _logger.trace("feasible freqs: {} - {}", ff.min, ff.max)
      layout(new ScrollPane(NonEditable(new Table((ff map (Array(_: Any))).toArray: Array[Array[Any]], Seq("Frequency (MHz)"))))) = Center
    } else {
      layout(new FixedFrequencyPanel) = Center
    }
  }

  listenTo(_cb)

  reactions += {
    case ButtonClicked(`_cb`) =>
      Job.job = Job.job.copy(dimensions = Job.job.dimensions.copy(frequency = _cb.selected))
  }

  update()
  Job += this
}
