package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail._

/** Selection-Detail panel controller for [[base.Architecture]].
 *  Controls instances of [[view.selection.ArchitecturesPanel]] and
 *  [[view.detail.ArchitectureDetailPanel]].
 *  @constructor Create new instance of controller.
 */
class ArchitecturesPanelController extends {
  val architectures = new ArchitecturesPanel
  val details   = new ArchitectureDetailPanel
} with SelectionDetailViewController(ViewController(architectures), ViewController(details)) {
  // details view should listen to selection view
  architectures.Selection += details
}
