//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
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
