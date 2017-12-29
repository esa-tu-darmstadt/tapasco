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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.core
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing.GridPanel

/** Panel that displays an estimation for area utilization and max. frequency for
 *  the currently configured Composition. Uses a GridPanel, where each
 *  [[base.Architecture]] has its own row and each [[base.Platform]] its own
 *  column.
 *
 *  @note Currently all reports must be available (requirement).
 */
class CompositionSummariesPanel extends GridPanel(
    Job.job.architectures.size,
    Job.job.platforms.size) with Listener[Job.Event] {
  // listen to model changes
  Job += this

  /** Update set of summary panels if composition changes. */
  def update(e: Job.Event): Unit = {
    contents.clear()
    rows = Job.job.architectures.size
    columns = Job.job.platforms.size
    if (! Job.job.initialComposition.isEmpty) {
      for (t <- Job.job.targets) {
        contents += new CompositionTargetSummaryPanel(Config.configuration,
          Job.job.initialComposition, t)
      }
    }
    revalidate()
  }
}
