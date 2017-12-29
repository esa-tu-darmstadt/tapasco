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
import  view.View

/** The controller package contains all view controllers in iTPC.
 *  iTPC loosely adheres to the ''Model-View-Controller (MVC)'' paradigm:
 *  [[ViewController]] instances create the [[view.View]] instances they control
 *  and listen to their event publications. In turn they modify the data model
 *  and update the [[view.View]].
 */
package object controller {
  /** A ViewController controls one [[view.View]] instance. */
  trait ViewController {
    /** Returns the controlled [[view.View]]. */
    def view: View
    /** Returns subordinate [[ViewController]] instances managed by this one. */
    def controllers: Seq[ViewController]
  }

  object ViewController {
    /** Construct a default empty ViewController from a given [[view.View]].
     *  @param v [[view.View]] instance.
     *  @return Minimal view controller for the view.
     */
    def apply(v: View): ViewController = new ViewController {
      override def view: View = v
      override def controllers: Seq[ViewController] = Seq()
    }
  }
}
