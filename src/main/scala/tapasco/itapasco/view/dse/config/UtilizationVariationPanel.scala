package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.base.Composition
import  de.tu_darmstadt.cs.esa.tapasco.dse.DesignSpace
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  scala.swing.event._
import  scala.swing.BorderPanel.Position._
import  Job.Events._

/** UtilizationVariationPanel shows UI elements to configure the area variation
 *  dimension in the design space. It can be enabled/disabled by a checkbox on
 *  top; if enabled, variations of the composition will be presented in a table
 *  below in descending order of their area.
 *
 *  @see [[dse.DesignSpace]]
 */
class UtilizationVariationPanel extends BorderPanel with Listener[Job.Event] {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] var state   = !Job.job.dimensions.utilization
  private[this] val _cb     = new CheckBox("Utilization Variation") { selected = state }

  def update(e: Job.Event): Unit = e match {
    case JobChanged(job) => update()
  }

  private def update(): Unit = if (state != Job.job.dimensions.utilization) {
    _logger.trace("switching to new state: {}", Job.job.dimensions.utilization)
    Swing.onEDT {
      state = Job.job.dimensions.utilization
      _cb.selected = state
      layout.clear()
      layout(new FlowPanel { contents += _cb }) = North
      if (Job.job.dimensions.utilization) {
        val compositions = DesignSpace.feasibleCompositions(Job.job.target, Job.job.initialComposition)
        _logger.trace("number of feasible compositions: %d".format(compositions.length))
        val cs = (compositions map (c => Array(c.toString: Any))).toArray
        if (cs.length > 0) {
          val hs = (0 until compositions(0).composition.length map (i =>
            Seq("Core %d".format(i), "#")) fold Seq()) (_ ++ _)
          def mk(c: Composition): Array[Any] = (c.composition map { ce =>
            Array(ce.kernel: Any, ce.count: Any)
          } fold Array()) (_ ++ _)
          val ds = (compositions map (mk _)).toArray
          layout(new ScrollPane(NonEditable(new Table(ds, hs) { enabled = false }))) = Center
        }
      }
      revalidate()
      repaint()
    }
  } else {
    _logger.trace("state already matches: {}", state)
  }

  listenTo(_cb)

  reactions += {
    case ButtonClicked(`_cb`) =>
      Job.job = Job.job.copy(dimensions = Job.job.dimensions.copy(utilization = _cb.selected))
  }

  update()
  Job += this
}
