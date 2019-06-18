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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.ArchitecturesPanel
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.base.Architecture
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  ArchitecturesPanel.Events._
import  scala.swing.ScrollPane

/** Detail panel for [[base.Architecture]] instances.
 *  Uses a [[common.DescriptionPropertiesTable]] to show details.
 */
class ArchitectureDetailPanel extends ScrollPane with Listener[ArchitecturesPanel.Event] {
  def update(e: ArchitecturesPanel.Event): Unit = e match {
    case ArchitectureSelected(od) => update(od)
  }

  private def update(od: Option[Architecture]): Unit = {
    viewportView = new DescriptionPropertiesTable(od)
    revalidate()
  }
}
