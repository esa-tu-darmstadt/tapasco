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
package de.tu_darmstadt.cs.esa.tapasco.itapasco

/** iTPC loosely adheres to the 'Model-View-Controller (MVC)' paradigm; this
 *  package contains all 'View' classes, i.e., UI elements.
 *  Most views are Selection/Detail, the packages [[view.selection]] and
 *  [[view.detail]] contain the classes in these categories. Note that some
 *  UI elements that have been reused intensively are also found in
 *  [[itapasco.common]].
 */
package object view {
  /** Base type for views. */
  type View = scala.swing.Component
}
