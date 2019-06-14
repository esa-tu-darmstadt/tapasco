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
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{BoxPanel, Button, Orientation}

/** TaskPanel instances show tables for the queued, running and completed [[task.Task]]s
 *  of a [[task.Tasks]] instance.
 *  Each of the tables is a [[common.QueuePanel]] instance in a ScrollPane.
 *  It registers with [[globals.TaskScheduler]] to track the tasks.
 */
class TaskPanel extends BoxPanel(Orientation.Vertical) with Listener[Tasks.Event] {
  private[this] val queued    = new QueuePanel("Queued tasks:",    () => TaskScheduler.queued)
  private[this] val running   = new QueuePanel("Running tasks:",   () => TaskScheduler.running)
  private[this] val completed = new QueuePanel("Completed tasks:", () => TaskScheduler.complete, Some(() => clear()))
  // listen to queue events
  Seq(queued, running, completed) foreach { _.Selection += QueuePanelListener }

  private def updateAll = {
    queued.update()
    running.update()
    completed.update()
  }

  def update(e: Tasks.Event): Unit = {
    updateAll
    revalidate()
  }

  private val b = new Button("add")

  contents += queued
  contents += running
  contents += completed
  // contents += b

  listenTo(b)
  reactions += {
    case scala.swing.event.ButtonClicked(b) => {
      // scalastyle:off regex magic.number
      TaskScheduler("Waiting", () => { Thread.sleep(5000); println("YAY"); true }, b => {})
      // scalastyle:on regex magic.number
    }
  }

  TaskScheduler += this

  /** Selection is [[util.Publisher]] notifying of task selection events. */
  object Selection extends Publisher { type Event = TaskPanel.Event }

  /** Clear completed task list. */
  def clear(): Unit = TaskScheduler.clearCompleted()

  /** Listen to selection events in any of the three tables. */
  private object QueuePanelListener extends Listener[QueuePanel.Event] {
    import QueuePanel.Events._
    def update(e: QueuePanel.Event): Unit = e match {
      case TaskSelected(ot) => Selection.publish(TaskPanel.Events.TaskSelected(ot))
    }
  }
}

object TaskPanel {
  sealed trait Event
  final object Events {
    /** Raised when a task was selected for detail view. */
    final case class TaskSelected(ot: Option[Task]) extends Event
  }
}

