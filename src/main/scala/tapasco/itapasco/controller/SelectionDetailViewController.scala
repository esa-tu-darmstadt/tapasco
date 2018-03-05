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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.SelectionAndDetailPanel
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view._

/** View controller for [[common.SelectionAndDetailPanel]] views.
 *  Provides a basic view controller for selection-detail panels which consist
 *  of a 'selection' part on top, where user can select or configure something,
 *  and a 'detail' part below, where details for the currently selected entity
 *  are displayed.
 *
 *  @see [[common.SelectionAndDetailPanel]]
 *
 *  @constructor Create new instance from given selection and detail controllers.
 *  @param selection Selection view controller (top).
 *  @param detail Detail view controller (bottom).
 */
class SelectionDetailViewController(val selection: ViewController, val detail: ViewController) extends ViewController {
  override val view: View = new SelectionAndDetailPanel(selection.view, detail.view)
  override val controllers: Seq[ViewController] = Seq(selection, detail)
}

object SelectionDetailViewController {
  /** Factory method from [[view.View]] instances.
   *  Instantiates minimal [[ViewController]] instances for the views and
   *  produces a [[SelectionDetailViewController]].
   *
   *  @param selectionView Selection view.
   *  @param detailView Detail view.
   */
  def apply(selectionView: View, detailView: View): SelectionDetailViewController =
    new SelectionDetailViewController(ViewController(selectionView), ViewController(detailView))
}
