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
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.AppState.Events._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.AppState.States._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Action, MenuBar, MenuItem}
import  javax.swing.KeyStroke
import  java.awt.Toolkit

/** iTPC main menu.
 *  @constructor Create new menu.
 */
class AppMenu extends MenuBar with Listener[AppState.Event] {
  import AppMenu.Events._

  /** Publisher for the menu events. */
  object Publisher extends Publisher {
    type Event = AppMenu.Event
  }

  /** Menu "File": Contains load, save and exit menu items. */
  object FileMenu extends scala.swing.Menu("File") {
    // load configuration
    private val loadAction = Action("Load Configuration ...") { Publisher.publish(LoadConfiguration) }
    loadAction.accelerator = Some(KeyStroke.getKeyStroke('L',
        Toolkit.getDefaultToolkit().getMenuShortcutKeyMask()))

    // save configuration
    private val saveAction = Action("Save Configuration ...") { Publisher.publish(SaveConfiguration) }
    saveAction.accelerator = Some(KeyStroke.getKeyStroke('S',
        Toolkit.getDefaultToolkit().getMenuShortcutKeyMask()))

    // debug:
    private val debugAction = Action("Dump states") { Publisher.publish(DumpDebugInfo) }
    // exit
    val exitAction = Action("Exit") { Publisher.publish(Exit) }
    exitAction.accelerator = Some(KeyStroke.getKeyStroke('Q',
      Toolkit.getDefaultToolkit().getMenuShortcutKeyMask()))

    private val actions = Seq(loadAction, saveAction, /*debugAction,*/ exitAction)
    val items = actions map (new MenuItem(_))
    def apply(a: scala.swing.Action): MenuItem = items(actions.indexOf(a))
    contents ++= items
  }

  def update(e: AppState.Event): Unit = e match {
    case StateChanged(s) => s match {
      case Normal => FileMenu.items foreach { _.enabled = true }
      case DesignSpaceExploration =>
        FileMenu.items foreach { _.enabled = false }
        FileMenu(FileMenu.exitAction).enabled = true
    }
  }

  contents += FileMenu
}

object AppMenu {
  sealed trait Event
  final object Events {
    /** Load configuration menu item was clicked. */
    final case object LoadConfiguration extends Event
    /** Save configuration menu item was clicked. */
    final case object SaveConfiguration extends Event
    /** Dump debug menu item was clicked. */
    final case object DumpDebugInfo extends Event
    /** Exit menu item was clicked. */
    final case object Exit extends Event
  }
}
