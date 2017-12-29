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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{BorderPanel, Label, ScrollPane, Table}

/** An ElementDetailPanel shows a table with details for a [[dse.DesignSpace.Element]].
 *  Currently the composition, its description, the design frequency and the heuristic
 *  value of the element are shown.
 */
class ElementDetailPanel extends BorderPanel {
  private[this] final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private var _element: Option[DesignSpace.Element] = None
  private final val noElement = new Label("no element selected")
  layout(noElement) = BorderPanel.Position.Center

  /** Returns the element data is being displayed for. */
  def element: Option[DesignSpace.Element] = _element
  /** Sets the element data is being displayed for. */
  def element_=(e: DesignSpace.Element) {
    _element = Some(e)
    loadData(e)
  }

  private def loadData(e: DesignSpace.Element) {
    layout(new ScrollPane(new ElementDetailPanel.ElementDetailTable(e))) = BorderPanel.Position.Center
    revalidate()
    repaint()
  }
}

private object ElementDetailPanel {
  import LogFormatter._

  private class ElementDetailTable(e: DesignSpace.Element)
      extends Table(ElementDetailPanel.mkData(e), Seq("Property", "Value")) {
    model = NonEditable(model)
    peer.getTableHeader().setReorderingAllowed(false)

    if (rowCount > 0) {
      val cols = 0 until peer.getColumnCount() map { i => (i, peer.getColumnModel().getColumn(i)) }
      cols foreach { case (cidx, col) =>
        val maxwidth  = col.getMaxWidth()
        val bestwidth = (for {
          ridx <- 0 until rowCount
          c = peer.prepareRenderer(peer.getCellRenderer(ridx, cidx), ridx, cidx)
        } yield c.getPreferredSize().width + peer.getIntercellSpacing().width).max
        col.setPreferredWidth(if (bestwidth > maxwidth) maxwidth else bestwidth)
      }
    }
  }

  private def mkData(e: DesignSpace.Element): Array[Array[Any]] = Array(
    Array("Composition", logformat(e.composition.composition)),
    Array("Description", e.composition.description getOrElse ""),
    Array("Frequency", e.frequency),
    Array("Heuristic Value (h)", e.h)
  )
}
