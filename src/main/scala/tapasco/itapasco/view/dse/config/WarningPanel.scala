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
