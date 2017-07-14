package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.dse.log._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Swing, Table}
import  scala.swing.event._
import  ExplorationLogTable.Events._

/**
 * Table for an Exploration log.
 * Uses [[ExplorationLogTableModel]] to keep log of events in an Exploration.
 **/
class ExplorationLogTable extends Table {
  private[this] val _eltm = new ExplorationLogTableModel
  val explorationListeners: Seq[Listener[Exploration.Event]] = Seq(_eltm)

  final val TIMESTAMP_COLUMN_WIDTH = 192

  def event: Option[Exploration.Event] = if (selection.rows.isEmpty) {
    None
  } else {
    Some(_eltm(selection.rows.min))
  }

  def setLogEvents(l: ExplorationLog) { _eltm.setLogEvents(l) }

  object EventSelection extends Publisher {
    type Event = ExplorationLogTable.Event
  }

  model = _eltm
  selection.elementMode = Table.ElementMode.Row
  selection.intervalMode = Table.IntervalMode.Single
  peer.getTableHeader().setReorderingAllowed(false)
  peer.setColumnSelectionAllowed(false)
  private def updateWidths() = {
    peer.getColumnModel().getColumn(0).setPreferredWidth(TIMESTAMP_COLUMN_WIDTH)
    peer.getColumnModel().getColumn(1).setPreferredWidth(peer.getBounds().width - TIMESTAMP_COLUMN_WIDTH)
  }
  Swing.onEDT { updateWidths() }

  listenTo(this.selection)
  listenTo(this)
  reactions += {
    case UIElementResized(_) => updateWidths()
    case TableRowsSelected(_, _, _) => {
      event foreach {
        e => EventSelection.publish(EventSelected(e))
      }
      updateWidths()
    }
  }
}

object ExplorationLogTable {
  sealed trait Event { def event: Exploration.Event }
  final object Events {
    final case class EventSelected(event: Exploration.Event) extends Event
  }
}
