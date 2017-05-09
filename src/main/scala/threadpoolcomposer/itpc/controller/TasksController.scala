package de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.controller
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.selection._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.detail._

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
