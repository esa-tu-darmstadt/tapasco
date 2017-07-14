package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  edu.uci.ics.jung.visualization.VisualizationViewer
import  scala.swing.{BorderPanel, Component, Label, Swing}
import  java.awt.geom.Point2D

/** MainGraphPanel shows [[globals.Graph.mainViewer]] in a resizable panel.
 *  The trait [[Centering]] is mixed-in, facilitating programmable control of
 *  the viewport.
 */
class MainGraphPanel extends BorderPanel with Centering[N, E] {
  layout(new Label("no graph")) = BorderPanel.Position.Center
  _center     = new Point2D.Double(50.0, -50.0)
  _scalePoint = new Point2D.Double(120.0, -120.0)
  override def vv: VisualizationViewer[N, E] = Graph.mainViewer

  Graph += new Listener[Graph.Event] {
    import Graph.Events._
    def update(e: Graph.Event): Unit = e match {
      case GraphChanged => Swing.onEDT {
        val g = Component.wrap(Graph.mainViewer)
        layout(g) = BorderPanel.Position.Center
        revalidate()
        repaint()
        listenTo(g)
      }
      case ExplorationChanged(oe) => oe foreach { _ += new Listener[Exploration.Event] {
        def update(e: Exploration.Event) { Swing.onEDT { repaint() } }
      }}
      case _ => {}
    }
  }

  reactions += {
    case scala.swing.event.UIElementResized(_) =>
      try {
        recenter()
        rescale()
      } catch { case _: Throwable => {} }
  }
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
