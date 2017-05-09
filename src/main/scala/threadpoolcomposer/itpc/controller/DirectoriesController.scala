package de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.controller
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.selection._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.detail._

/** SelectionDetailController for base path configuration.
 *  Controls a [[view.selection.DirectoriesPanel]] and a [[view.detail.DirectoryDetailPanel]].
 */
class DirectoriesController extends {
  val directories = new DirectoriesPanel
  val details     = new DirectoryDetailPanel
} with SelectionDetailViewController(ViewController(directories), ViewController(details)) {
  // details view should listen to selection view
  directories.Selection += details
}
