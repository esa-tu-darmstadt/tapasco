package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.slurm.Slurm.Events._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  scala.swing.event._
import  scala.swing.BorderPanel.Position._

/** Displays a checkbox to enable/disable SLURM support.
 *  @note Will be deactivated if SLURM is unavailable.
 *  @see [[slurm.Slurm]]
 */
class SlurmPanel extends BorderPanel with Listener[Slurm.Event] {
  private val cbSlurm = new CheckBox("enable SLURM batch mode") {
    enabled = Slurm.available
    selected = Slurm.enabled
  }

  def update(e: Slurm.Event): Unit = e match {
    case SlurmModeEnabled(en) => cbSlurm.selected = en
  }

  layout(new FlowPanel {
    contents += cbSlurm
  }) = Center

  listenTo(cbSlurm)
  reactions += {
    case ButtonClicked(`cbSlurm`) => Slurm.enabled = cbSlurm.selected
  }

  Slurm += this
}
