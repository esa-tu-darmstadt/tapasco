package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail._

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
