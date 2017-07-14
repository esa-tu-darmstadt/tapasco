package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.util._

/** DSE configuration panel: Configure batch size in DSE run. */
class BatchSizePanel extends SliderPanel(
    svalue = Job.job.batchSize,
    smin = BatchSizePanel.BATCH_SZ_MIN,
    smax = BatchSizePanel.BATCH_SZ_MAX,
    valueChanged = v => Job.job = Job.job.copy(batchSize = v),
    valueFormat = v => "%3d".format(v),
    labelText = Some("Batch size:"),
    toolTip = Some("Number of parallel runs in each DSE step.")) {
  Job += new Listener[Job.Event] {
    def update(e: Job.Event): Unit = e match {
      case Job.Events.JobChanged(job) => value = job.batchSize
    }
  }
}

private object BatchSizePanel {
  final val BATCH_SZ_MIN = 1
  final val BATCH_SZ_MAX = 200
}
