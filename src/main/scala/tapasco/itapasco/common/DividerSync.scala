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
import  scala.swing.Reactor
import  scala.swing.event._

/** Synchronizes the split locations of two [[TripleSplitPanel]] instances.
 *  @constructor Create new instance.
 *  @param tsp0 First split panel.
 *  @param tsp1 Second split panel.
 */
class DividerSync(tsp0: TripleSplitPanel, tsp1: TripleSplitPanel) extends Reactor {
  listenTo(tsp0.left, tsp0.right, tsp1.left, tsp1.right)
  reactions += {
    case UIElementResized(e) => e match {
      case tsp0.left   => tsp1.dividerLocations.left  = tsp0.dividerLocations.left
      case tsp0.right  => tsp1.dividerLocations.right = tsp0.dividerLocations.right
      case tsp1.left   => tsp0.dividerLocations.left  = tsp1.dividerLocations.left
      case tsp1.right  => tsp0.dividerLocations.right = tsp1.dividerLocations.right
      case _           => {}
    }
  }
}
