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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  scala.swing.{Component, SplitPane, Swing, Orientation}

// scalastyle:off null
/** Extension of SplitPanel with three elements.
 *  @note Uses nested SplitPanel instances.
 *  @constructor Create a new instance.
 *  @param left Component on the left side.
 *  @param center Component in the middle.
 *  @param right Component on the right side.
 */
class TripleSplitPanel(val left: Component, val center: Component, val right: Component)
    extends SplitPane(Orientation.Vertical) {
  private val subsplit = new SplitPane(Orientation.Vertical) {
    leftComponent = left
    rightComponent = center
    border = null
    dividerSize = 2
  }
  leftComponent  = subsplit
  rightComponent = right
  border = null
  dividerSize = 2
  /** Divider locations for left and right split divider. */
  object dividerLocations {
    /** Returns the width of the left component. */
    def left: Int                = subsplit.dividerLocation
    /** Sets the width of the left component. */
    def left_=(v: Int): Unit     = if (v > 0) Swing.onEDT { subsplit.dividerLocation = v }
    /** Sets the width percentage of the left component. */
    def left_=(v: Double): Unit  = if (v > 0.0 && v < 1.0) Swing.onEDT { subsplit.dividerLocation = v }
    /** Returns the width of the right component. */
    def right: Int               = dividerLocation
    /** Sets the width of the right component. */
    def right_=(v: Int): Unit    = if (v > 0) Swing.onEDT { dividerLocation = v }
    /** Sets the width percentage of the right component. */
    def right_=(v: Double): Unit = if (v > 0.0 && v < 1.0) Swing.onEDT { dividerLocation = v }
  }
}
// scalastyle:on null
