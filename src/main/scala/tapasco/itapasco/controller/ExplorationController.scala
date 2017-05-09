package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.View
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Component, BorderPanel}

/** Main controller for the DSE page.
 *  Switches between a [[ExplorationConfigController]] (when no DSE is running)
 *  and the live view via [[ExplorationGraphController]] automatically by
 *  listening to [[globals.TaskScheduler]].
 */
class ExplorationController extends ViewController {
  private lazy val cfgController = new ExplorationConfigController
  private lazy val dseController = new ExplorationGraphController
  private val tp                 = new ExplorationController.TogglePanel(cfgController.view)
  override val view: View        = tp
  override def controllers: Seq[ViewController] = Seq(cfgController, dseController)

  TaskScheduler += new Listener[Tasks.Event] {
    import Tasks.Events._
    def update(e: Tasks.Event): Unit = e match {
      case TaskStarted(_, t)   => t match {
        case et: ExplorationTask => tp.set(dseController.view)
        case _                   => {}
      }
      case _                   => {}
    }
  }

  dseController.egp += new Listener[ExplorationGraphPanel.Event] {
    def update(e: ExplorationGraphPanel.Event): Unit = e match {
      case ExplorationGraphPanel.Events.ExitRequested => tp.set(cfgController.view)
      case _ => {}
    }
  }
}

private object ExplorationController {
  /** BorderPanel that can change its Center component at runtime. */
  private class TogglePanel(initialComponent: Component) extends BorderPanel {
    def set(c: Component) {
      layout(c) = BorderPanel.Position.Center
      revalidate()
      repaint()
    }
    set(initialComponent)
  }
}
