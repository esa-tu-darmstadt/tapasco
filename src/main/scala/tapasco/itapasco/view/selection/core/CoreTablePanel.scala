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
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table._
import  de.tu_darmstadt.cs.esa.tapasco.base.{Description, Kernel}
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.ScrollPane
import  scala.swing.event.TableRowsSelected

/** CoreTablePanel displays a CoreTable and listens to its selection object to
 *  update the currently selected Core/Kernel in the model detail.
 **/
class CoreTablePanel extends ScrollPane with Publisher {
  type Event = CoreTablePanel.Event
  import CoreTablePanel.Events._

  private[this] val _mainTable = new CoreTable
  private[this] val PREFERRED_HEIGHT = 100

  viewportView = _mainTable
  listenTo(_mainTable.selection)
  preferredSize = new java.awt.Dimension(0, PREFERRED_HEIGHT)

  reactions += {
    case TableRowsSelected(_, rng, false) => publish(CoreSelected(_mainTable.description()))
  }

  _mainTable += new Listener[CoreTable.Event] {
    def update(e: CoreTable.Event): Unit = e match {
      case CoreTable.Events.HighLevelSynthesisRequested(k) =>
        publish(HighLevelSynthesisRequested(k))
      case _ => {}
    }
  }
}

object CoreTablePanel {
  sealed trait Event
  object Events {
    /** Raised when user selects an element from the table. */
    final case class CoreSelected(od: Option[Description]) extends Event
    /** Raised when user clicks on of the HLS buttons in the table. */
    final case class HighLevelSynthesisRequested(k: Kernel) extends Event
  }
}
