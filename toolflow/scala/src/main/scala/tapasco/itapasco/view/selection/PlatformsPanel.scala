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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table._
import  de.tu_darmstadt.cs.esa.tapasco.base.Platform
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{BorderPanel, ScrollPane}
import  scala.swing.BorderPanel.Position._
import  scala.swing.event._
import  PlatformsPanel.Events._

/**
 * PlatformsPanel shows a list of Platforms the user can select
 * from for the current configuration.
 **/
class PlatformsPanel extends BorderPanel {
  private[this] val _table  = new PlatformsTable

  object Selection extends Publisher { type Event = PlatformsPanel.Event }

  layout(new ScrollPane(_table)) = Center
  listenTo(_table.selection)
  reactions += {
    case TableRowsSelected(`_table`, _, false) => Selection.publish(PlatformSelected(_table.platform))
  }
}

object PlatformsPanel {
  sealed trait Event
  final object Events {
    final case class PlatformSelected(op: Option[Platform]) extends Event
  }
}
