package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail._

/** PlatformsPanelController is a Selection/Detail view for [[base.Platform]]s.
 *  Selection controls a [[view.selection.PlatformsPanel]], detail controls a
 *  [[view.detail.PlatformDetailPanel]]. User can select Platforms to use for
 *  the current run, the detail view will present additional information, like
 *  the benchmark results.
 */
class PlatformsPanelController extends {
  val platforms = new PlatformsPanel
  val details   = new PlatformDetailPanel
} with SelectionDetailViewController(ViewController(platforms), ViewController(details)) {
  // details view should listen to selection view
  platforms.Selection += details
}

