package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{BorderPanel, Button, Label, ScrollPane, Swing, Table}
import  scala.swing.BorderPanel.Position._
import  scala.swing.event._
import  java.time.format.DateTimeFormatter, java.time.format.FormatStyle
import  QueuePanel.Events._

/**
 * A BorderPanel which shows a list of [[task.Task]] instances in a queue.
 * @param m MVC model.
 * @param label Description of the queue.
 * @param tasks Function to query current state of the list (will be called repeatedly).
 * @param onClear If not None, will present a button with label 'Clear', which triggers
                  this action when clicked.
 **/
class QueuePanel(
    label: String,
    tasks: () => Seq[Task],
    onClear: Option[() => Unit] = None) extends BorderPanel {
  // scalastyle:off magic.number
  private[this] val _dateFormat = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT)

  private def taskToArray(t: Task): Array[Any] = Array(
    t.description,
    t.queued map (_dateFormat.format(_)) getOrElse "",
    t.started map (_dateFormat.format(_)) getOrElse "",
    t.completed map (_dateFormat.format(_)) getOrElse ""
  )

  private def tasksToTable(tasks: Seq[Task]): Array[Array[Any]] =
    (tasks map (taskToArray(_))).toArray

  private def mkTable(tasks: Seq[Task]): Table = new Table(
    tasksToTable(tasks),
    Seq("Task", "Queued at", "Started at", "Completed at")
  ) {
    selection.elementMode = scala.swing.Table.ElementMode.Row
    val m = model
    model = new javax.swing.table.AbstractTableModel {
      def getColumnCount(): Int = m.getColumnCount()
      def getRowCount(): Int = m.getRowCount()
      def getValueAt(row: Int, col: Int): Object = m.getValueAt(row, col)
      override def isCellEditable(row: Int, col: Int): Boolean = false
      override def getColumnName(col: Int): String = m.getColumnName(col)
    }

    // auto-resize columns
    val cols = 0 until peer.getColumnCount() map { i => (i, peer.getColumnModel().getColumn(i)) }
    cols foreach { case (cidx, col) => col.setPreferredWidth(if (cidx == 0) 800 else 150) }
  }

  def update(): Unit = {
    val tbl = mkTable(tasks())
    listenTo(tbl.selection)
    layout(new ScrollPane(tbl) {
      preferredSize = new java.awt.Dimension(0, tbl.rowHeight * 5)
    }) = Center
  }

  object Selection extends Publisher { type Event = QueuePanel.Event }

  reactions += {
    case TableRowsSelected(t, rng, false) => Selection.publish(TaskSelected(tasks().lift(rng.min)))
  }

  layout(new BorderPanel {
    layout(new Label(label) { border = Swing.EmptyBorder(8, 0, 4, 0) }) = West
    onClear map { clear =>
      val b = new Button("Clear") { preferredSize = new java.awt.Dimension(80, 16) }
      layout(b) = East
      listenTo(b)
      reactions += {
        case ButtonClicked(bt) => if (bt.equals(b)) clear() else {}
      }
    }
  }) = North

  update()
  // scalastyle:on magic.number
}

object QueuePanel {
  sealed trait Event
  final object Events {
    final case class TaskSelected(ot: Option[Task]) extends Event
  }
}
