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
import  de.tu_darmstadt.cs.esa.tapasco.base.Platform
import  scala.swing._

protected[itapasco] final class PlatformsTable extends Table {
  private[this] val _ptm = new PlatformsTableModel
  private[this] final val COLWIDTH_TIMESTAMP = 128

  model = _ptm
  selection.elementMode = Table.ElementMode.Row
  selection.intervalMode = Table.IntervalMode.Single
  peer.getTableHeader().setReorderingAllowed(false)
  peer.setColumnSelectionAllowed(false)
  peer.getColumnModel().getColumn(1).setMaxWidth(COLWIDTH_TIMESTAMP)

  def platform: Option[Platform] = if (selection.rows.isEmpty) {
    None
  } else {
    Some(_ptm(selection.rows.min))
  }
}
