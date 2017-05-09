package de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.selection
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.table._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.base.Architecture
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.util._
import  scala.swing.{BorderPanel, ScrollPane}
import  scala.swing.BorderPanel.Position._
import  scala.swing.event.TableRowsSelected
import  ArchitecturesPanel.Events._

/**
 * Shows a list of available Architectures:
 * Architectures can be selected or deselected for current config.
 **/
class ArchitecturesPanel extends BorderPanel with Publisher {
  private[this] val _table  = new ArchitecturesTable

  object Selection extends Publisher { type Event = ArchitecturesPanel.Event }

  layout(new ScrollPane(_table)) = Center
  listenTo(_table.selection)
  reactions += {
    case TableRowsSelected(`_table`, _, false) => Selection.publish(ArchitectureSelected(_table.architecture))
  }
}

object ArchitecturesPanel {
  sealed trait Event
  object Events {
    final case class ArchitectureSelected(oa: Option[Architecture]) extends Event
  }
}
