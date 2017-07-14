package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Button, BorderPanel, GridPanel, Label, ScrollPane, SplitPane, Orientation}
import  scala.swing.event.{ButtonClicked, UIElementResized}

/**
 * ExplorationGraphPanel provides a complete UI view of a [[model.DesignSpaceGraph]],
 * including a graph view, several detail views, a log view and a minimap of the graph.
 *
 * The center consists of a [[MainGraphPanel]], which is framed by some detail panels,
 * showing element and report details for picked elements. In the bottom there is an
 * [[view.table.ExplorationLogTable]], which shows a textual history of the DSE run by
 * detailing the DSE events in chronological order. In the bottom right corner a
 * [[SatelliteGraphPanel]] with minimap of the design space is shown.
 *
 * @see ExplorationController, ExplorationGraphController
 */
class ExplorationGraphPanel(help: Option[String] = None) extends SplitPane(Orientation.Horizontal) with Publisher {
  type Event = ExplorationGraphPanel.Event
  val reportPanel: Seq[ReportPanel]   = 0 until 3 map { _ => new ReportPanel }
  val detailPanel: ElementDetailPanel = new ElementDetailPanel
  val mainGraph                       = new MainGraphPanel
  val elog: ExplorationLogTable       = new ExplorationLogTable
  val escroll: ScrollPane             = new ScrollPane(elog)
  val exitBt: Button                  = new Button("Exit Design Space Exploration") { visible = false }

  private val lreports  = new GridPanel(2, 1) {
    contents += detailPanel
    contents += reportPanel(0)
  }
  private val rreports  = new GridPanel(2, 1) {
    contents += reportPanel(1)
    contents += reportPanel(2)
  }
  private val middle    = new BorderPanel {
    help foreach { h =>
      val legend = new Label(h) {
        font = font.deriveFont(font.getSize * 0.9f)
        foreground = java.awt.Color.gray
      }
      layout(legend)    = BorderPanel.Position.North
    }
    layout(mainGraph) = BorderPanel.Position.Center
    layout(exitBt)    = BorderPanel.Position.South
  }
  private val satGraph  = new SatelliteGraphPanel
  private val upper     = new TripleSplitPanel(lreports, middle, rreports)
  private val lower     = new SplitPane(Orientation.Vertical, escroll, satGraph) {
    // scalastyle:off null
    border = null
    // scalastyle:on null
    dividerSize = 2
  }
  leftComponent         = upper
  rightComponent        = lower

  def exitEnabled: Boolean = exitBt.visible
  def exitEnabled_=(b: Boolean) { exitBt.visible = b; revalidate(); repaint() }

  def resetDividers() {
    upper.dividerLocations.right = 0.8
    upper.dividerLocations.left  = 0.2 * 1.2
    lower.dividerLocation        = 0.8
    dividerLocation              = 0.75
  }

  reactions += {
    case UIElementResized(_)     => resetDividers()
    case ButtonClicked(`exitBt`) => publish(ExplorationGraphPanel.Events.ExitRequested)
  }
  listenTo(this, upper, exitBt)
}

object ExplorationGraphPanel {
  sealed trait Event
  object Events {
    final case object ExitRequested extends Event
  }
}
