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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._

/** Status panel is a UI element showing a single status line.
 *  It shows the number of running tasks and consumed resources.
 */
class StatusPanel extends BorderPanel with Listener[Tasks.Event] {
  import StatusPanel._
  private def mkText(tasks: Tasks): String = Seq(
    "%s".format(tasks.resourceStatus),
    "%d tasks queued".format(tasks.queued.length),
    "%d tasks running".format(tasks.running.length),
    "%d tasks completed   ".format(tasks.complete.length)
  ) mkString ", " replace (",", " |")

  private[this] val _label = new Label("") {
    foreground = STATUS_FG_COLOR
  }

  def update(e: Tasks.Event): Unit = {
    _label.text = mkText(e.source)
    revalidate()
  }

  background = STATUS_BG_COLOR
  border = Swing.CompoundBorder(
    Swing.BeveledBorder(Swing.Lowered),
    Swing.EmptyBorder(STATUS_BORDER_SZ))

  layout(_label) = BorderPanel.Position.East
}

object StatusPanel {
  /** Status bar text color. */
  final val STATUS_FG_COLOR  = java.awt.Color.white
  // scalastyle:off magic.number
  /** Status bar background color. */
  final val STATUS_BG_COLOR  = new java.awt.Color(50, 50, 70)
  // scalastyle:on magic.number
  /** Status bar border width. */
  final val STATUS_BORDER_SZ = 2
}
