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
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail._

/** TasksController is a Selection/Detail view for [[task.Task]]s.
 *  Selection controls a [[view.selection.TaskPanel]] showing the queued, running
 *  and completed tasks in [[common.QueuePanel]]s. Detail controls a
 *  [[view.detail.TaskDetailPanel]], which tracks the logs of the selected task.
 */
class TasksController extends {
  val tasksSel = new TaskPanel
  val tasksDet = new TaskDetailPanel
} with SelectionDetailViewController(ViewController(tasksSel), ViewController(tasksDet)) {
  tasksSel.Selection += tasksDet
}
