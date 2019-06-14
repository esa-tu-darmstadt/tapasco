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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.dse.log._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Swing, Table}
import  scala.swing.event._
import  ExplorationLogTable.Events._

/**
 * Table for an Exploration log.
 * Uses [[ExplorationLogTableModel]] to keep log of events in an Exploration.
 **/
class ExplorationLogTable extends Table {
  private[this] val _eltm = new ExplorationLogTableModel
  val explorationListeners: Seq[Listener[Exploration.Event]] = Seq(_eltm)

  final val TIMESTAMP_COLUMN_WIDTH = 192

  def event: Option[Exploration.Event] = if (selection.rows.isEmpty) {
    None
  } else {
    Some(_eltm(selection.rows.min))
  }

  def setLogEvents(l: ExplorationLog) { _eltm.setLogEvents(l) }

  object EventSelection extends Publisher {
    type Event = ExplorationLogTable.Event
  }

  model = _eltm
  selection.elementMode = Table.ElementMode.Row
  selection.intervalMode = Table.IntervalMode.Single
  peer.getTableHeader().setReorderingAllowed(false)
  peer.setColumnSelectionAllowed(false)
  private def updateWidths() = {
    peer.getColumnModel().getColumn(0).setPreferredWidth(TIMESTAMP_COLUMN_WIDTH)
    peer.getColumnModel().getColumn(1).setPreferredWidth(peer.getBounds().width - TIMESTAMP_COLUMN_WIDTH)
  }
  Swing.onEDT { updateWidths() }

  listenTo(this.selection)
  listenTo(this)
  reactions += {
    case UIElementResized(_) => updateWidths()
    case TableRowsSelected(_, _, _) => {
      event foreach {
        e => EventSelection.publish(EventSelected(e))
      }
      updateWidths()
    }
  }
}

object ExplorationLogTable {
  sealed trait Event { def event: Exploration.Event }
  final object Events {
    final case class EventSelected(event: Exploration.Event) extends Event
  }
}
