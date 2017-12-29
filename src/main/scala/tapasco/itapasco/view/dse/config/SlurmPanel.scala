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
