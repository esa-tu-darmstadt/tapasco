package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.dse.Exploration.Events._
import  de.tu_darmstadt.cs.esa.tapasco.dse.log._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  de.tu_darmstadt.cs.esa.tapasco.util.LogFormatter._
import  scala.collection.mutable.ArrayBuffer
import  javax.swing.table.AbstractTableModel
import  java.time.LocalDateTime
import  java.time.format.DateTimeFormatter, java.time.format.FormatStyle

/**
 * Table model that keeps and exploration log.
 * Listens to an Exploration and logs all events with timestamp or replays
 * the given log object.
 * @param exploration Either Exploration to listen to, or ExplorationLog to replay.
 **/
final class ExplorationLogTableModel extends AbstractTableModel with Listener[Exploration.Event] {
  private[this] val _log: ArrayBuffer[(LocalDateTime, Exploration.Event)] = new ArrayBuffer()
  private[this] val _dateFormat = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM)

  def update(e: Exploration.Event): Unit = e match {
    case RunDefined(_, _) => {}
    case _ =>
      _log.synchronized { _log += ((LocalDateTime.now(), e)) }
      fireTableDataChanged()
  }

  def apply(row: Int): Exploration.Event = _log(row)._2

  override def getColumnCount(): Int = 2
  override def getColumnName(col: Int): String = if (col == 0) "Timestamp" else "Event"
  override def getRowCount(): Int = _log.synchronized { _log.length }
  override def getValueAt(row: Int, col: Int): Object = if (col == 0) {
    _dateFormat.format((_log.synchronized { _log(row) })._1)
  } else {
    formatEvent((_log.synchronized { _log(row) })._2)
  }
  override def isCellEditable(row: Int, col: Int): Boolean = false
  override def setValueAt(o: Object, row: Int, col: Int): Unit = {}

  private[table] def setLogEvents(log: ExplorationLog) { _log.clear(); _log ++= log.events }

  // scalastyle:off cyclomatic.complexity
  private def formatEvent(e: Exploration.Event): String = e match {
    case RunDefined(e, u) =>
      "Run defined: %s, utilization = %1.2f".format(logformat(e), u.utilization)
    case RunStarted(e, _) =>
      "Run started: %s".format(logformat(e))
    // TODO check: maybe the event itself should use Option[Task]?
    case RunFinished(e, t) =>
      "Run finished: %s, result: %s".format(logformat(e), Option(t) map {
        _.composerResult map { cr => cr.result.toString } getOrElse "None"
      } getOrElse("<replay mode>"))
    case RunGenerated(f, e, u) =>
      "Feedback element generated: %s from %s (utilization = %1.2f)"
        .format(logformat(e), logformat(f), u.utilization)
    case RunPruned(es, c, r) =>
      "%s: pruned %d elements for %s".format(r.toString, es.length,
        logformat(c))
    case BatchStarted(n, es) =>
      "Starting batch #%d with %d elements".format(n, es.length)
    case BatchFinished(n, es, rs) =>
      "Batch #%d finished: %s".format(n, rs map (_.result) mkString ", ")
    // TODO check: maybe the event itself should use Option[Exploration]?
    case ExplorationStarted(ex) => Option(ex) map { _ =>
      ("Starting exploration for target %s@%s, initial composition = %s, " +
       "batch size = %d, dimensions = %s").format(ex.target.ad.name,
        ex.target.pd.name, logformat(ex.initialComposition), ex.batchSize,
        ex.dimensions.toString) } getOrElse ("Exploration started")
    case ExplorationFinished(ex) => Option(ex) map { _ =>
      "Design space exploration finished: %s".format(
        ex.result map { case (e, _) => logformat(e) } getOrElse "no solution found"
      ) } getOrElse ("Exploration finished")
  }
  // scalastyle:on cyclomatic.complexity
}
