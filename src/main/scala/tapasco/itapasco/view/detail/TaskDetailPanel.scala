package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.TaskPanel
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.TaskPanel.Events._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  scala.swing.BorderPanel.Position._

/** TaskDetailPanel shows detail for a [[task.Task]].
 *  It consists of a table depicting basic data about the task, such as start
 *  and end times, and a [[LogTrackingPanel]] showing the contents of logfiles
 *  associated with this task.
 */
class TaskDetailPanel extends BorderPanel with Listener[TaskPanel.Event] {
  private[this] var _previous: Option[Component] = None
  private val dtf = java.time.format.DateTimeFormatter.ofLocalizedDateTime(
    java.time.format.FormatStyle.MEDIUM
  )
  private def isFinished(t: Task) = t.completed.nonEmpty
  private def mkTable(ot: Option[Task]) = ot map { t => new Table(
    Array(
      Array("Description",  t.description),
      Array("Result",       t.completed map (_ => t.result) getOrElse "N/A"),
      Array("Queued at",    t.queued map (dtf.format(_)) getOrElse ""),
      Array("Started at",   t.started map (dtf.format(_)) getOrElse ""),
      Array("Completed at", t.completed map (dtf.format(_)) getOrElse "")
    ): Array[Array[Any]],
    Seq("Property", "Value")
  )} getOrElse new Table(Array(Array("",""): Array[Any]), Seq("Property", "Value"))

  private def update(ot: Option[Task]): Unit = {
    _previous foreach { _ match {
      case log: LogTrackingPanel => log.stop()
      case _ => {}
    }}
    _previous = Some(ot map { _ match {
      case hls: Task with LogTracking => new LogTrackingPanel(hls)
      case _ => {
        val tbl = mkTable(ot)
        new ScrollPane(tbl) { preferredSize = new java.awt.Dimension(0, tbl.rowHeight * 6) }
      }
    }} getOrElse (new Label("no task selected")))
    _previous foreach { c => layout(c) = Center }
    revalidate()
  }

  def update(e: TaskPanel.Event): Unit = e match {
    case TaskSelected(ot) => update(ot)
    case _ => {}
  }
}
