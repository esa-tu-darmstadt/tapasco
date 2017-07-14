package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  Job.Events._

/** FixedFrequencyPanel shows a slider to adjust a fixed target design frequency.
  * @note Currently limited to values between 50 and 500 MHz.
  */
class FixedFrequencyPanel extends SliderPanel(
    svalue = Job.job.initialFrequency.toInt,
    smin = FixedFrequencyPanel.F_MIN,
    smax = FixedFrequencyPanel.F_MAX,
    valueChanged = v => Job.job = Job.job.copy(initialFrequency = v),
    valueFormat = v => "%3d MHz".format(v),
    labelText = Some("Frequency:"),
    toolTip = Some("Target design frequency for the processing elements.")) with Listener[Job.Event] {
  def update(e: Job.Event): Unit = e match {
    case JobChanged(job) => value = job.initialFrequency.toInt
  }

  Job += this
}

private object FixedFrequencyPanel {
  final val F_MIN =  50
  final val F_MAX = 500
}
