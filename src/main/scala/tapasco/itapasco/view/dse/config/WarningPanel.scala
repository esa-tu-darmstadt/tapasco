package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  scala.swing.BorderPanel.Position._

/** The warning panel is used to notify the user of possible misconfigurations.
 *  The most common one being to have selected a batch size larger than the
 *  number of processors in non-SLURM mode, potentially slowing down the batches
 *  significantly.
 */
class WarningPanel extends BorderPanel {
  private val batchSizeWarning =
    "Batch size is larger than number of physical processors, not all elements in a batch can be scheduled at once."
  private final val BORDER_SZ = 5
  private val bg = background
  private val warning = new TextArea() {
    editable = false
    wordWrap = true
    lineWrap = true
    background = bg
  }


  private def updateBatchSizeWarning(): Unit = {
    if (! Slurm.enabled && Job.job.batchSize > Runtime.getRuntime().availableProcessors()) {
      warning.text = batchSizeWarning
    } else {
      warning.text = ""
    }
  }

  border = Swing.EmptyBorder(BORDER_SZ)
  layout(warning) = Center

  Job += new Listener[Job.Event] {
    def update(e: Job.Event): Unit = e match {
      case Job.Events.JobChanged(job) => updateBatchSizeWarning
    }
  }

  Slurm += new Listener[Slurm.Event] {
    def update(e: Slurm.Event): Unit = updateBatchSizeWarning
  }
}
